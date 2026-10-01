# frozen_string_literal: true

# Lipgloss join / place / width / height / size and the version strings: a port of lipgloss v1.1.0
# join.go, position.go, size.go and whitespace.go, behind the same Ruby-side argument handling as the
# lipgloss gem 0.2.2 C extension (extension.c) and its Go glue (go/layout.go).
module R2UI
  module Compat
    module Gloss
      # Layout internals. The public entry points are the Lipgloss singleton methods defined below.
      module Layout
        UTF_8 = Encoding::UTF_8

        # Sentinel: the gem's JSON round trip ([]string unmarshal) failed, so join returns "".
        JSON_FAIL = Object.new.freeze

        extend self

        # --- Ruby C API argument conversions ------------------------------------------------------

        # The name rb_unexpected_type / rb_convert_type print for a value.
        def type_name(value)
          case value
          when nil then "nil"
          when true then "true"
          when false then "false"
          else value.class.name
          end
        end

        # Check_Type(value, T_STRING)
        def check_string(value)
          return if value.is_a?(String)

          raise TypeError, "wrong argument type #{type_name(value)} (expected String)"
        end

        # Check_Type(value, T_ARRAY)
        def check_array(value)
          return if value.is_a?(Array)

          raise TypeError, "wrong argument type #{type_name(value)} (expected Array)"
        end

        # StringValueCStr: implicit #to_str conversion, no NUL bytes.
        def c_string(value)
          str = String.try_convert(value)
          raise TypeError, "no implicit conversion of #{type_name(value)} into String" if str.nil?
          raise ArgumentError, "string contains null byte" if str.include?("\0")

          str
        end

        INT_MIN = -(2**31)
        INT_MAX = 2**31 - 1

        # NUM2INT (rb_num2int on a 64-bit platform).
        def num2int(value)
          raise TypeError, "no implicit conversion from nil to integer" if value.nil?

          i = case value
              when Integer then value
              when Float
                unless value.finite? && value < 9_223_372_036_854_775_808.0 && value >= -9_223_372_036_854_775_808.0
                  raise RangeError, "float #{float_out_of_range_repr(value)} out of range of integer"
                end

                value.to_i
              else
                conv = Integer.try_convert(value)
                raise TypeError, "no implicit conversion of #{type_name(value)} into Integer" if conv.nil?

                conv
              end
          if i.bit_length > 63
            raise RangeError, "#{i.negative? ? 'bignum too small' : 'bignum too big'} to convert into 'long'"
          end
          raise RangeError, "integer #{i} too small to convert to 'int'" if i < INT_MIN
          raise RangeError, "integer #{i} too big to convert to 'int'" if i > INT_MAX

          i
        end

        # NUM2DBL (rb_num2dbl).
        def num2dbl(value)
          case value
          when Float then value
          when Integer then value.to_f
          when String then raise TypeError, "no implicit conversion to float from string"
          when nil then raise TypeError, "no implicit conversion to float from nil"
          when true then raise TypeError, "no implicit conversion to float from true"
          when false then raise TypeError, "no implicit conversion to float from false"
          else
            raise TypeError, "can't convert #{type_name(value)} into Float" unless value.respond_to?(:to_f)

            f = value.to_f
            unless f.is_a?(Float)
              raise TypeError, "can't convert #{type_name(value)} to Float (#{type_name(value)}#to_f gives #{type_name(f)})"
            end

            f
          end
        end

        def float_out_of_range_repr(f)
          return f.to_s if f.nan? || f.infinite?

          format("%-.10g", f)
        end

        # rb_utf8_str_new_cstr(C.CString(result)): a fresh UTF-8 string, cut at the first NUL.
        def c_result(str)
          s = String.new(str, encoding: UTF_8)
          nul = s.b.index("\0")
          s = s.byteslice(0, nul).force_encoding(UTF_8) if nul
          s
        end

        # The gem passes the array to Go as JSON (Array#to_json) and unmarshals it into []string. A
        # JSON string element survives, null becomes "", anything else fails the whole unmarshal.
        # Objects without a JSON representation of their own serialize as their #to_s string.
        def json_strings(array)
          array.map do |e|
            case e
            when String then e
            when nil then ""
            when Symbol then e.to_s
            when Numeric, true, false, Array, Hash then return JSON_FAIL
            else e.to_s
            end
          end
        end

        # --- lipgloss v1.1.0 ----------------------------------------------------------------------

        def str_width(s) = Text.string_width(s)

        # Position.value(): clamped to [0, 1].
        def pos_value(pos)
          [1.0, [0.0, pos].max].min
        end

        # get.go getLines
        def get_lines(s)
          lines = s.split("\n", -1)
          lines = [""] if lines.empty?
          widest = 0
          lines.each do |l|
            w = str_width(l)
            widest = w if w > widest
          end
          [lines, widest]
        end

        def join_horizontal(pos, strs)
          return "" if strs.empty?
          return strs[0] if strs.length == 1

          blocks = []
          max_widths = []
          max_height = 0
          strs.each do |str|
            lines, w = get_lines(str)
            blocks << lines
            max_widths << w
            max_height = lines.length if lines.length > max_height
          end

          blocks.map! do |block|
            next block if block.length >= max_height

            n = max_height - block.length
            extra = Array.new(n, "")
            if pos == 0.0
              block + extra
            elsif pos == 1.0
              extra + block
            else
              split = (n * pos_value(pos)).round
              top = n - split
              bottom = n - top
              Array.new(n - top, "") + block + Array.new(n - bottom, "")
            end
          end

          b = +""
          rows = blocks[0].length
          rows.times do |i|
            blocks.each_with_index do |block, j|
              b << block[i]
              pad = max_widths[j] - str_width(block[i])
              b << (" " * pad) if pad.positive?
            end
            b << "\n" if i < rows - 1
          end
          b
        end

        def join_vertical(pos, strs)
          return "" if strs.empty?
          return strs[0] if strs.length == 1

          blocks = []
          max_width = 0
          strs.each do |str|
            lines, w = get_lines(str)
            blocks << lines
            max_width = w if w > max_width
          end

          b = +""
          blocks.each_with_index do |block, i|
            block.each_with_index do |line, j|
              w = max_width - str_width(line)
              if pos == 0.0
                b << line << spaces(w)
              elsif pos == 1.0
                b << spaces(w) << line
              elsif w < 1
                b << line
              else
                split = (w * pos_value(pos)).round
                right = w - split
                left = w - right
                b << spaces(left) << line << spaces(right)
              end
              b << "\n" unless i == blocks.length - 1 && j == block.length - 1
            end
          end
          b
        end

        def spaces(n) = n.positive? ? " " * n : ""

        def width(str)
          w = 0
          str.split("\n", -1).each do |l|
            lw = str_width(l)
            w = lw if lw > w
          end
          w
        end

        def height(str) = str.count("\n") + 1

        def place(width, height, hpos, vpos, str, ws)
          place_vertical(height, vpos, place_horizontal(width, hpos, str, ws), ws)
        end

        def place_horizontal(width, pos, str, ws)
          lines, content_width = get_lines(str)
          gap = width - content_width
          return str if gap <= 0

          b = +""
          lines.each_with_index do |l, i|
            short = [0, content_width - str_width(l)].max
            total = gap + short
            if pos == 0.0
              b << l << ws.render(total)
            elsif pos == 1.0
              b << ws.render(total) << l
            else
              split = (total * pos_value(pos)).round
              left = total - split
              right = total - left
              b << ws.render(left) << l << ws.render(right)
            end
            b << "\n" if i < lines.length - 1
          end
          b
        end

        def place_vertical(height, pos, str, ws)
          content_height = str.count("\n") + 1
          gap = height - content_height
          return str if gap <= 0

          _, width = get_lines(str)
          empty_line = ws.render(width)
          b = +""
          if pos == 0.0
            b << str << "\n"
            gap.times do |i|
              b << empty_line
              b << "\n" if i < gap - 1
            end
          elsif pos == 1.0
            b << ((empty_line + "\n") * gap) << str
          else
            split = (gap * pos_value(pos)).round
            top = gap - split
            bottom = gap - top
            b << ((empty_line + "\n") * top) << str
            bottom.times { b << "\n" << empty_line }
          end
          b
        end

        # whitespace.go: fills gaps with (optionally styled) characters.
        class Whitespace
          def initialize(chars: "", foreground: nil)
            @chars = chars
            @foreground = foreground
          end

          # Built at render time, as Go builds it inside Place (newWhitespace).
          def style
            r = Renderer.default
            s = r.color_profile.string
            s = s.foreground(@foreground.color(r)) if @foreground
            s
          end

          def render(width)
            chars = @chars.empty? ? " " : @chars
            runes = chars.dup.force_encoding(UTF_8).each_char.map { |c| c.valid_encoding? ? c : "�" }
            j = 0
            b = +""
            i = 0
            while i < width
              b << runes[j]
              j += 1
              j = 0 if j >= runes.length
              i += Text.string_width(runes[j])
            end
            short = width - Text.string_width(b)
            b << (" " * short) if short.positive?

            s = style
            s.styled(b)
          end
        end

        PLAIN_WHITESPACE = Whitespace.new.freeze

        # The whitespace options lipgloss_place_rb reads from its keyword hash, converted in the C
        # extension's order. Returns [whitespace, light, dark] where light/dark are still to be
        # converted (after the numeric arguments) for an adaptive foreground.
        def whitespace_options(opts)
          ws_chars_v = opts[:whitespace_chars]
          ws_fg_v = opts[:whitespace_foreground]
          ws_chars = ws_chars_v.nil? ? "" : c_string(ws_chars_v)

          if !ws_fg_v.nil? && ws_fg_v.respond_to?(:light) && ws_fg_v.respond_to?(:dark)
            [:adaptive, ws_chars, ws_fg_v.light, ws_fg_v.dark]
          else
            ws_fg = ws_fg_v.nil? ? "" : c_string(ws_fg_v)
            fg = ws_fg.empty? ? nil : TerminalColor::Color.new(ws_fg.dup)
            [:plain, ws_chars, fg]
          end
        end
      end
    end
  end
end

module Lipgloss
  class << self
    def _join_horizontal(position, strings)
      layout = R2UI::Compat::Gloss::Layout
      layout.check_array(strings)
      strs = layout.json_strings(strings)
      pos = layout.num2dbl(position)
      return layout.c_result("") if strs.equal?(layout::JSON_FAIL)

      layout.c_result(layout.join_horizontal(pos, strs))
    end

    def _join_vertical(position, strings)
      layout = R2UI::Compat::Gloss::Layout
      layout.check_array(strings)
      strs = layout.json_strings(strings)
      pos = layout.num2dbl(position)
      return layout.c_result("") if strs.equal?(layout::JSON_FAIL)

      layout.c_result(layout.join_vertical(pos, strs))
    end

    def width(string)
      layout = R2UI::Compat::Gloss::Layout
      layout.check_string(string)
      layout.width(layout.c_string(string))
    end

    def height(string)
      layout = R2UI::Compat::Gloss::Layout
      layout.check_string(string)
      layout.height(layout.c_string(string))
    end

    def size(string)
      layout = R2UI::Compat::Gloss::Layout
      layout.check_string(string)
      s = layout.c_string(string)
      [layout.width(s), layout.height(s)]
    end

    def _place(*args, **opts)
      unless args.length == 5
        raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 5)"
      end

      layout = R2UI::Compat::Gloss::Layout
      width, height, hpos, vpos, string = args
      layout.check_string(string)

      ws = layout::PLAIN_WHITESPACE
      unless opts.empty?
        kind, chars, *rest = layout.whitespace_options(opts)
        if kind == :adaptive
          light, dark = rest
          w = layout.num2int(width)
          h = layout.num2int(height)
          hp = layout.num2dbl(hpos)
          vp = layout.num2dbl(vpos)
          str = layout.c_string(string)
          light = layout.c_string(light)
          dark = layout.c_string(dark)
          fg = (light.empty? && dark.empty?) ? nil : R2UI::Compat::Gloss::TerminalColor::AdaptiveColor.new(light.dup, dark.dup)
          ws = layout::Whitespace.new(chars: chars.dup, foreground: fg)
          return layout.c_result(layout.place(w, h, hp, vp, str, ws))
        end

        ws = layout::Whitespace.new(chars: chars.dup, foreground: rest[0])
      end

      w = layout.num2int(width)
      h = layout.num2int(height)
      hp = layout.num2dbl(hpos)
      vp = layout.num2dbl(vpos)
      str = layout.c_string(string)
      layout.c_result(layout.place(w, h, hp, vp, str, ws))
    end

    def _place_horizontal(width, position, string)
      layout = R2UI::Compat::Gloss::Layout
      layout.check_string(string)
      w = layout.num2int(width)
      pos = layout.num2dbl(position)
      str = layout.c_string(string)
      layout.c_result(layout.place_horizontal(w, pos, str, layout::PLAIN_WHITESPACE))
    end

    def _place_vertical(height, position, string)
      layout = R2UI::Compat::Gloss::Layout
      layout.check_string(string)
      h = layout.num2int(height)
      pos = layout.num2dbl(position)
      str = layout.c_string(string)
      layout.c_result(layout.place_vertical(h, pos, str, layout::PLAIN_WHITESPACE))
    end

    def upstream_version
      String.new(R2UI::Compat::Gloss::UPSTREAM_VERSION, encoding: Encoding::UTF_8)
    end

    def version
      format("lipgloss v%s (upstream %s) [Go native extension]", const_get(:VERSION), upstream_version)
    end
  end
end
