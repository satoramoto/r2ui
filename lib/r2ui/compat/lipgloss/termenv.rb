# frozen_string_literal: true

# Terminal colors and SGR styling: a port of muesli/termenv v0.16.0 (profiles, colors, Style, and the
# Unix color-profile / background detection) plus lipgloss v1.1.0 color.go and renderer.go.
#
# API used by Lipgloss::Style (mirrors termenv / lipgloss Go names):
#
#   R2UI::Compat::Gloss::Termenv
#     Profile::TRUE_COLOR / ANSI256 / ANSI / ASCII     termenv.Profile values (frozen Profile objects)
#     Profile.resolve(:true_color | :ansi256 | :ansi | :ascii | Profile) -> Profile
#     Profile#color(str)    -> termenv color or nil     (Profile.Color: "#hex", "0".."255", "" -> nil)
#     Profile#convert(c)    -> color or nil             (Profile.Convert: degrade to the profile)
#     Profile#string        -> Style                    (Profile.String(): a Style for this profile)
#     NoColor.new / ANSIColor.new(n) / ANSI256Color.new(n) / RGBColor.new("#hex")
#       #sequence(bg = false) -> "31", "38;5;123", "48;2;1;2;3", "" (Color.Sequence)
#     Termenv.convert_to_rgb(c) -> Colorful::Color       (ConvertToRGB)
#     Style.new(profile = Profile::TRUE_COLOR)          (termenv.Style; Style{} is TrueColor in Go)
#       #bold #faint #italic #underline #overline #blink #reverse #cross_out  -> new Style
#       #foreground(color_or_nil) #background(color_or_nil)                   -> new Style (nil: no-op)
#       #styled(str) -> "\e[<seq>m" + str + "\e[0m", or str for ASCII / no styles / empty sequence
#     Output.new(io: STDOUT, env: ENV)                  termenv.Output: color_profile, env_color_profile,
#                                                       env_no_color?, tty?, background_color,
#                                                       has_dark_background?
#
#   R2UI::Compat::Gloss::Renderer                        lipgloss.Renderer; the default one is global
#     Renderer.default                                  the renderer Lipgloss uses
#     Renderer.color_profile -> Termenv::Profile        detected lazily, once (EnvColorProfile on stdout)
#     Renderer.has_dark_background? -> bool             detected lazily, once (OSC 11 query on a TTY)
#     Renderer.terminal_color(value, adaptive: true, complete: true, strict: true)
#                                                       Ruby color value -> TerminalColor, validated like
#                                                       the C extension (raises the same TypeErrors)
#     Renderer.color(value) -> termenv color or nil     terminal_color(value).color(Renderer.default)
#     Test hooks (r2ui only): Renderer.color_profile = :true_color | :ansi256 | :ansi | :ascii | nil,
#     Renderer.has_dark_background = true | false | nil, Renderer.reset!   (nil re-enables detection)
#
#   R2UI::Compat::Gloss::TerminalColor                   lipgloss TerminalColor implementations
#     Color.new(str), NoColor.new, AdaptiveColor.new(light, dark),
#     CompleteColor.new(true_color, ansi256, ansi), CompleteAdaptiveColor.new(light_cc, dark_cc)
#       #color(renderer = Renderer.default) -> termenv color or nil;  #rgba -> [r, g, b, a] (16-bit)
#
# Typical render (lipgloss style.go):
#   r  = Renderer.default
#   te = r.color_profile.string.bold.foreground(fg.color(r)).background(bg.color(r))
#   te.styled("text")
module R2UI
  module Compat
    module Gloss
      module Termenv
        ESC = "\e"
        BEL = "\a"
        CSI = "#{ESC}[".freeze
        OSC = "#{ESC}]".freeze
        ST = "#{ESC}\\".freeze

        RESET_SEQ = "0"
        BOLD_SEQ = "1"
        FAINT_SEQ = "2"
        ITALIC_SEQ = "3"
        UNDERLINE_SEQ = "4"
        BLINK_SEQ = "5"
        REVERSE_SEQ = "7"
        CROSS_OUT_SEQ = "9"
        OVERLINE_SEQ = "53"

        FOREGROUND = "38"
        BACKGROUND = "48"

        # termenv ansiHex: the 16 ANSI colors, the 6x6x6 cube and the 24 grays.
        ANSI_HEX = begin
          base = %w[#000000 #800000 #008000 #808000 #000080 #800080 #008080 #c0c0c0
                    #808080 #ff0000 #00ff00 #ffff00 #0000ff #ff00ff #00ffff #ffffff]
          levels = [0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff]
          cube = (0...216).map { |i| format("#%02x%02x%02x", levels[i / 36], levels[(i / 6) % 6], levels[i % 6]) }
          grays = (0...24).map { |i| format("#%02x%02x%02x", 8 + 10 * i, 8 + 10 * i, 8 + 10 * i) }
          (base + cube + grays).map(&:freeze).freeze
        end

        class Error < StandardError; end

        # termenv.NoColor: no sequence at all (but still appended to a Style as "").
        class NoColor
          def sequence(_bg = false)
            ""
          end

          def to_s
            ""
          end

          def ==(other)
            other.is_a?(NoColor)
          end
          alias eql? ==

          def hash
            NoColor.hash
          end
        end

        # termenv.ANSIColor (0-15; other values still produce a sequence, as in Go).
        ANSIColor = Struct.new(:value) do
          def sequence(bg = false)
            col = value
            bg_mod = ->(c) { bg ? c + 10 : c }
            return (bg_mod.call(col) + 30).to_s if col < 8

            (bg_mod.call(col - 8) + 90).to_s
          end

          def to_s
            ANSI_HEX.fetch(value, "")
          end
        end

        # termenv.ANSI256Color (16-255).
        ANSI256Color = Struct.new(:value) do
          def sequence(bg = false)
            "#{bg ? BACKGROUND : FOREGROUND};5;#{value}"
          end

          def to_s
            ANSI_HEX.fetch(value, "")
          end
        end

        # termenv.RGBColor: a "#rrggbb" (or "#rgb") string.
        RGBColor = Struct.new(:value) do
          def sequence(bg = false)
            f = Colorful.hex(value)
            return "" if f.nil?

            channels = [f.r, f.g, f.b].map { |v| Colorful.go_uint8(v * 255) }
            "#{bg ? BACKGROUND : FOREGROUND};2;#{channels.join(';')}"
          end

          def to_s
            value
          end
        end

        module_function

        # termenv.ConvertToRGB. Unknown colors (and Go's out-of-range palette indexes, which panic in
        # Go) come back as black, like colorful.Hex("") does.
        def convert_to_rgb(color)
          hex = case color
                when RGBColor then color.value
                when ANSIColor, ANSI256Color
                  color.value.between?(0, 255) ? ANSI_HEX[color.value] : ""
                else ""
                end
          Colorful.hex(hex) || Colorful::Color.new(0.0, 0.0, 0.0)
        end

        def ansi256_to_ansi_color(color)
          h = Colorful.hex(ANSI_HEX.fetch(color.value)) # Go panics on an out-of-range index
          best = 0
          md = Float::MAX
          16.times do |i|
            d = h.distance_hsluv(Colorful.hex(ANSI_HEX[i]))
            if d < md
              md = d
              best = i
            end
          end
          ANSIColor.new(best)
        end

        def hex_to_ansi256_color(c)
          v2ci = lambda do |v|
            if v < 48 then 0
            elsif v < 115 then 1
            else ((v - 35) / 40).to_i
            end
          end
          r = v2ci.call(c.r * 255.0)
          g = v2ci.call(c.g * 255.0)
          b = v2ci.call(c.b * 255.0)
          ci = 36 * r + 6 * g + b
          i2cv = [0, 0x5f, 0x87, 0xaf, 0xd7, 0xff]
          cr = i2cv[r]
          cg = i2cv[g]
          cb = i2cv[b]

          average = (r + g + b) / 3
          gray_idx = if average > 238
                       23
                     else
                       (average - 3).fdiv(10).truncate # Go integer division truncates toward zero
                     end
          gv = 8 + 10 * gray_idx

          c2 = Colorful::Color.new(cr / 255.0, cg / 255.0, cb / 255.0)
          g2 = Colorful::Color.new(gv / 255.0, gv / 255.0, gv / 255.0)
          return ANSI256Color.new(16 + ci) if c.distance_hsluv(c2) <= c.distance_hsluv(g2)

          ANSI256Color.new(232 + gray_idx)
        end

        # strconv.Atoi: optional sign, decimal digits, must fit in int64.
        def atoi(str)
          return nil unless str.match?(/\A[+-]?[0-9]+\z/)

          i = str.to_i
          i.between?(-2**63, 2**63 - 1) ? i : nil
        end

        # termenv.Profile.
        class Profile
          attr_reader :value, :name

          CACHE_LIMIT = 4096

          def initialize(value, name, sym)
            @value = value
            @name = name
            @sym = sym
            @cache = {} # Profile#color results; degrading to ANSI costs ~2ms per color
            freeze
          end

          def to_sym
            @sym
          end

          def inspect
            "#<Termenv::Profile #{@name}>"
          end

          TRUE_COLOR = new(0, "TrueColor", :true_color)
          ANSI256 = new(1, "ANSI256", :ansi256)
          ANSI = new(2, "ANSI", :ansi)
          ASCII = new(3, "Ascii", :ascii)
          ALL = [TRUE_COLOR, ANSI256, ANSI, ASCII].freeze

          def self.resolve(profile)
            return profile if profile.is_a?(Profile)

            ALL.find { |p| p.to_sym == profile } ||
              raise(ArgumentError, "unknown color profile #{profile.inspect} (use :true_color, :ansi256, :ansi or :ascii)")
          end

          # Profile.String: a new Style for this profile.
          def string
            Style.new(self)
          end

          # Profile.Convert. Returns nil for an unparsable RGB color, as Go does.
          def convert(color)
            return NoColor.new if equal?(ASCII)

            case color
            when ANSIColor then color
            when ANSI256Color
              equal?(ANSI) ? Termenv.ansi256_to_ansi_color(color) : color
            when RGBColor
              h = Colorful.hex(color.value)
              return nil if h.nil?
              return color if equal?(TRUE_COLOR)

              ac = Termenv.hex_to_ansi256_color(h)
              equal?(ANSI) ? Termenv.ansi256_to_ansi_color(ac) : ac
            else color
            end
          end

          # Profile.Color: "#..." is RGB, an integer below 16 is ANSI, any other integer is ANSI256,
          # anything else (including "") is nil.
          def color(str)
            str = str.to_s
            return nil if str.empty?
            return @cache[str] if @cache.key?(str)

            c = if str.start_with?("#")
                  RGBColor.new(str.dup.freeze)
                else
                  i = Termenv.atoi(str)
                  i.nil? ? nil : (i < 16 ? ANSIColor.new(i) : ANSI256Color.new(i))
                end
            c = convert(c)&.freeze unless c.nil?
            @cache.clear if @cache.size >= CACHE_LIMIT
            @cache[str.dup.freeze] = c
          end
        end

        # termenv.Style: an immutable list of SGR parameters for one profile.
        class Style
          attr_reader :profile, :styles

          def initialize(profile = Profile::TRUE_COLOR, styles = [])
            @profile = Profile.resolve(profile)
            @styles = styles.dup.freeze
            freeze
          end

          def styled(str)
            return str if @profile.equal?(Profile::ASCII)
            return str if @styles.empty?

            seq = @styles.join(";")
            return str if seq.empty?

            "#{CSI}#{seq}m#{str}#{CSI}#{RESET_SEQ}m"
          end

          def foreground(color)
            color.nil? ? self : with(color.sequence(false))
          end

          def background(color)
            color.nil? ? self : with(color.sequence(true))
          end

          def bold = with(BOLD_SEQ)
          def faint = with(FAINT_SEQ)
          def italic = with(ITALIC_SEQ)
          def underline = with(UNDERLINE_SEQ)
          def overline = with(OVERLINE_SEQ)
          def blink = with(BLINK_SEQ)
          def reverse = with(REVERSE_SEQ)
          def cross_out = with(CROSS_OUT_SEQ)

          private

          def with(seq)
            Style.new(@profile, @styles + [seq])
          end
        end

        # termenv.Output for a file (stdout by default): color profile and background detection as
        # termenv_unix.go does it.
        class Output
          OSC_TIMEOUT = 5.0 # seconds per byte, as termenv's OSCTimeout

          # TIOCGPGRP, for termenv's isForeground check.
          TIOCGPGRP = case RUBY_PLATFORM
                      when /darwin|bsd/ then 0x40047477
                      when /linux/ then 0x540F
                      end

          attr_reader :io, :env

          # io:          the terminal output (termenv uses os.Stdout).
          # env:         anything with #[] (ENV by default).
          # assume_tty:  true forces the TTY checks to pass (termenv WithTTY), nil asks the io.
          # osc_timeout: seconds to wait for each byte of a terminal reply.
          def initialize(io: STDOUT, env: ENV, assume_tty: nil, osc_timeout: OSC_TIMEOUT)
            @io = io
            @env = env
            @assume_tty = assume_tty
            @osc_timeout = osc_timeout
          end

          def getenv(key)
            @env[key].to_s
          end

          def tty?
            return true if @assume_tty
            return false unless getenv("CI").empty?

            @io.respond_to?(:tty?) && @io.tty?
          rescue IOError
            false
          end

          def env_no_color?
            !getenv("NO_COLOR").empty? || (getenv("CLICOLOR") == "0" && !cli_color_forced?)
          end

          def env_color_profile
            return Profile::ASCII if env_no_color?

            p = color_profile
            return Profile::ANSI if cli_color_forced? && p.equal?(Profile::ASCII)

            p
          end

          def cli_color_forced?
            forced = getenv("CLICOLOR_FORCE")
            !forced.empty? && forced != "0"
          end

          def color_profile
            return Profile::ASCII unless tty?
            return Profile::TRUE_COLOR if getenv("GOOGLE_CLOUD_SHELL") == "true"

            term = getenv("TERM")
            case getenv("COLORTERM").downcase
            when "24bit", "truecolor"
              return Profile::ANSI256 if term.start_with?("screen") && getenv("TERM_PROGRAM") != "tmux"

              return Profile::TRUE_COLOR
            when "yes", "true"
              return Profile::ANSI256
            end

            case term
            when "alacritty", "contour", "rio", "wezterm", "xterm-ghostty", "xterm-kitty"
              return Profile::TRUE_COLOR
            when "linux", "xterm"
              return Profile::ANSI
            end
            return Profile::ANSI256 if term.include?("256color")
            return Profile::ANSI if term.include?("color") || term.include?("ansi")

            Profile::ASCII
          end

          # Output.BackgroundColor (uncached; lipgloss's Renderer caches the dark/light answer).
          def background_color
            return NoColor.new unless tty?

            begin
              s = term_status_report(11)
              c = xterm_color(s)
              return c if c
            rescue Error, SystemCallError, IOError
              nil
            end

            colorfgbg = getenv("COLORFGBG")
            if colorfgbg.include?(";")
              i = Termenv.atoi(colorfgbg.split(";", -1).last)
              return ANSIColor.new(i) if i
            end

            ANSIColor.new(0)
          end

          def has_dark_background?
            _h, _s, l = Termenv.convert_to_rgb(background_color).hsl
            l < 0.5
          end

          # termenv xTermColor: "\e]11;rgb:rrrr/gggg/bbbb" + BEL / ESC / ST -> RGBColor, or nil.
          def xterm_color(str)
            return nil if str.bytesize < 24 || str.bytesize > 25

            if str.end_with?(BEL) then str = str.delete_suffix(BEL)
            elsif str.end_with?(ESC) then str = str.delete_suffix(ESC)
            elsif str.end_with?(ST) then str = str.delete_suffix(ST)
            else return nil
            end
            str = str.byteslice(4..)
            return nil unless str.start_with?(";rgb:")

            parts = str.delete_prefix(";rgb:").split("/", -1)
            return nil if parts.size < 3 || parts[0, 3].any? { |p| p.bytesize < 2 } # Go would panic

            RGBColor.new("##{parts[0].byteslice(0, 2)}#{parts[1].byteslice(0, 2)}#{parts[2].byteslice(0, 2)}")
          end

          # termStatusReport: query the terminal with OSC <sequence>;? followed by a cursor position
          # request (which every terminal answers), with echo and canonical mode off. The terminal
          # mode is restored on every exit path.
          def term_status_report(sequence)
            term = getenv("TERM")
            raise Error, "unable to retrieve status report" if term.start_with?("screen", "tmux", "dumb")

            tty = tty_io
            raise Error, "unable to retrieve status report" if tty.nil?
            raise Error, "unable to retrieve status report" unless foreground?(tty)

            require "io/console"
            saved = tty.console_mode
            begin
              mode = saved.dup
              mode.raw!(intr: true)
              tty.console_mode = mode

              tty.syswrite("#{OSC}#{sequence};?#{ST}")
              tty.syswrite("#{CSI}6n")

              res, is_osc = read_next_response(tty)
              raise Error, "unable to retrieve status report" unless is_osc

              read_next_response(tty) # the cursor position reply, discarded
              res
            ensure
              tty.console_mode = saved
            end
          end

          private

          # A read/write handle on the output's file descriptor (Go reads replies from os.Stdout).
          def tty_io
            return @io if @io.respond_to?(:sysread) && !@io.equal?(STDOUT) && !@io.equal?($stdout)
            return nil unless @io.respond_to?(:fileno)

            @tty_io ||= IO.new(@io.fileno, "r+", autoclose: false)
          rescue SystemCallError, IOError, ArgumentError
            nil
          end

          def foreground?(tty)
            return false if TIOCGPGRP.nil?

            buf = [0].pack("l")
            tty.ioctl(TIOCGPGRP, buf)
            buf.unpack1("l") == Process.getpgrp
          rescue SystemCallError, IOError, NotImplementedError
            false
          end

          def read_next_byte(tty)
            raise Error, "timeout" if IO.select([tty], nil, nil, @osc_timeout).nil?

            tty.sysread(1)
          rescue EOFError
            raise Error, "EOF"
          end

          # readNextResponse: an OSC reply (ends in BEL or ESC) or a cursor position reply (ends in R).
          def read_next_response(tty)
            start = read_next_byte(tty)
            start = read_next_byte(tty) while start != ESC
            response = +start

            tpe = read_next_byte(tty)
            response << tpe
            osc = case tpe
                  when "[" then false
                  when "]" then true
                  else raise Error, "unable to retrieve status report"
                  end

            loop do
              b = read_next_byte(tty)
              response << b
              if osc
                return [response.force_encoding(Encoding::BINARY), true] if b == BEL || response.end_with?(ESC)
              elsif b == "R"
                return [response.force_encoding(Encoding::BINARY), false]
              end
              break if response.bytesize > 25
            end
            raise Error, "unable to retrieve status report"
          end
        end
      end

      # lipgloss TerminalColor implementations (color.go). Each resolves against a Renderer at render
      # time, like Go's TerminalColor.color(*Renderer).
      module TerminalColor
        # lipgloss.NoColor
        class NoColor
          def color(_renderer = Renderer.default)
            Termenv::NoColor.new
          end

          def rgba
            [0x0, 0x0, 0x0, 0xFFFF]
          end

          def ==(other)
            other.is_a?(NoColor)
          end
        end

        module RGBA
          def rgba(renderer = Renderer.default)
            c = Termenv.convert_to_rgb(color(renderer))
            conv = ->(v) { [[(v * 65_535.0 + 0.5).to_i, 0].max, 0xFFFF_FFFF].min }
            [conv.call(c.r), conv.call(c.g), conv.call(c.b), 0xFFFF]
          end
        end

        # lipgloss.Color: hex ("#ff8000", "#f80") or ANSI ("0".."255"); "" means no color.
        Color = Struct.new(:value) do
          include RGBA

          def color(renderer = Renderer.default)
            renderer.color_profile.color(value)
          end
        end

        # lipgloss.AdaptiveColor
        AdaptiveColor = Struct.new(:light, :dark) do
          include RGBA

          def color(renderer = Renderer.default)
            Color.new(renderer.has_dark_background? ? dark : light).color(renderer)
          end
        end

        # lipgloss.CompleteColor: exact values per profile, no degradation.
        CompleteColor = Struct.new(:true_color, :ansi256, :ansi) do
          include RGBA

          def color(renderer = Renderer.default)
            p = renderer.color_profile
            case p
            when Termenv::Profile::TRUE_COLOR then p.color(true_color)
            when Termenv::Profile::ANSI256 then p.color(ansi256)
            when Termenv::Profile::ANSI then p.color(ansi)
            else Termenv::NoColor.new
            end
          end
        end

        # lipgloss.CompleteAdaptiveColor
        CompleteAdaptiveColor = Struct.new(:light, :dark) do
          include RGBA

          def color(renderer = Renderer.default)
            (renderer.has_dark_background? ? dark : light).color(renderer)
          end
        end
      end

      # lipgloss.Renderer: caches the color profile and the dark-background answer, each detected
      # once on first use (Go's sync.Once), unless set explicitly.
      class Renderer
        attr_reader :output

        def initialize(output = Termenv::Output.new)
          @output = output
          @mutex = Mutex.new
          reset!
        end

        def color_profile
          @mutex.synchronize do
            @color_profile ||= @explicit_profile || @output.env_color_profile
          end
        end

        # nil re-enables detection (r2ui test hook; Go's SetColorProfile has no reset).
        def color_profile=(profile)
          @mutex.synchronize do
            @explicit_profile = profile.nil? ? nil : Termenv::Profile.resolve(profile)
            @color_profile = @explicit_profile
          end
        end

        def has_dark_background?
          @mutex.synchronize do
            return @explicit_dark unless @explicit_dark.nil?

            @dark = @output.has_dark_background? if @dark.nil?
            @dark
          end
        end

        # nil re-enables detection (r2ui test hook).
        def has_dark_background=(value)
          @mutex.synchronize do
            @explicit_dark = value.nil? ? nil : (value ? true : false)
            @dark = nil
          end
        end

        def reset!
          @mutex.synchronize do
            @explicit_profile = nil
            @color_profile = nil
            @explicit_dark = nil
            @dark = nil
          end
        end

        class << self
          def default
            @default ||= new
          end

          attr_writer :default

          def color_profile = default.color_profile
          def color_profile=(profile)
            default.color_profile = profile
          end

          def has_dark_background? = default.has_dark_background?
          def has_dark_background=(value)
            default.has_dark_background = value
          end

          def reset! = default.reset!

          # The Ruby color value -> TerminalColor conversion the C extension does (style.c
          # style_foreground / style_background):
          #   * responds to #light and #dark: if both answers respond to #true_color, #ansi256 and
          #     #ansi it is a CompleteAdaptiveColor, otherwise an AdaptiveColor of two strings;
          #   * responds to #true_color, #ansi256 and #ansi: CompleteColor;
          #   * otherwise it must be a String (Check_Type).
          # Strings inside composite colors go through StringValueCStr (implicit #to_str, no NUL).
          # Other setters accept less: border colors are adaptive: true, complete: false; margin
          # background is adaptive: false, complete: false; place's whitespace foreground is
          # complete: false, strict: false (StringValueCStr instead of Check_Type).
          def terminal_color(value, adaptive: true, complete: true, strict: true)
            if adaptive && adaptive_color?(value)
              light = value.light
              dark = value.dark
              if complete && complete_color?(light) && complete_color?(dark)
                return TerminalColor::CompleteAdaptiveColor.new(complete_from(light), complete_from(dark))
              end

              return TerminalColor::AdaptiveColor.new(c_string(light), c_string(dark))
            end
            return complete_from(value) if complete && complete_color?(value)

            check_string(value) if strict
            TerminalColor::Color.new(c_string(value))
          end

          def color(value, renderer = default)
            terminal_color(value).color(renderer)
          end

          def adaptive_color?(value)
            value.respond_to?(:light) && value.respond_to?(:dark)
          end

          def complete_color?(value)
            value.respond_to?(:true_color) && value.respond_to?(:ansi256) && value.respond_to?(:ansi)
          end

          private

          def complete_from(value)
            true_color = value.true_color
            ansi256 = value.ansi256
            ansi = value.ansi
            TerminalColor::CompleteColor.new(c_string(true_color), c_string(ansi256), c_string(ansi))
          end

          def check_string(value)
            return if value.is_a?(String)

            raise TypeError, "wrong argument type #{type_name(value)} (expected String)"
          end

          # StringValueCStr: implicit #to_str conversion, and no NUL bytes.
          def c_string(value)
            str = String.try_convert(value)
            raise TypeError, "no implicit conversion of #{type_name(value)} into String" if str.nil?
            raise ArgumentError, "string contains null byte" if str.include?("\0")

            str.dup.freeze
          end

          def type_name(value)
            case value
            when nil, true, false then value.inspect
            else value.class.to_s
            end
          end
        end
      end
    end
  end
end
