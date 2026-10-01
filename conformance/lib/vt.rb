# frozen_string_literal: true

module Conformance
  # A small VT/xterm screen model: feed it the bytes a program writes to its
  # terminal and read back the resulting screen as text plus style runs.
  # Behaviour follows xterm (BCE, pending wrap, DECSC contents, alt screens).
  class VT
    ATTR_NAMES = %w[bold faint italic underline blink reverse invisible strike].freeze
    BOLD = 1
    FAINT = 2
    ITALIC = 4
    UNDERLINE = 8
    BLINK = 16
    REVERSE = 32
    INVISIBLE = 64
    STRIKE = 128

    Pen = Data.define(:attrs, :fg, :bg)
    DEFAULT_PEN = Pen.new(attrs: 0, fg: nil, bg: nil)

    TRACKED_FLAGS = [1, 1004, 1006, 2004].freeze
    MOUSE_MODES = [9, 1000, 1001, 1002, 1003].freeze
    TRACKED_MOUSE = [1000, 1002, 1003].freeze

    # DEC Special Graphics (ESC ( 0), 0x5f..0x7e.
    DEC_GRAPHICS = {
      0x5f => " ", 0x60 => "◆", 0x61 => "▒", 0x62 => "␉", 0x63 => "␌", 0x64 => "␍",
      0x65 => "␊", 0x66 => "°", 0x67 => "±", 0x68 => "␤", 0x69 => "␋", 0x6a => "┘",
      0x6b => "┐", 0x6c => "┌", 0x6d => "└", 0x6e => "┼", 0x6f => "⎺", 0x70 => "⎻",
      0x71 => "─", 0x72 => "⎼", 0x73 => "⎽", 0x74 => "├", 0x75 => "┤", 0x76 => "┴",
      0x77 => "┬", 0x78 => "│", 0x79 => "≤", 0x7a => "≥", 0x7b => "π", 0x7c => "≠",
      0x7d => "£", 0x7e => "·"
    }.freeze

    # East Asian Wide/Fullwidth and emoji-presentation ranges (two cells).
    WIDE = [
      [0x1100, 0x115F], [0x231A, 0x231B], [0x2329, 0x232A], [0x23E9, 0x23EC], [0x23F0, 0x23F0],
      [0x23F3, 0x23F3], [0x25FD, 0x25FE], [0x2614, 0x2615], [0x2648, 0x2653], [0x267F, 0x267F],
      [0x2693, 0x2693], [0x26A1, 0x26A1], [0x26AA, 0x26AB], [0x26BD, 0x26BE], [0x26C4, 0x26C5],
      [0x26CE, 0x26CE], [0x26D4, 0x26D4], [0x26EA, 0x26EA], [0x26F2, 0x26F3], [0x26F5, 0x26F5],
      [0x26FA, 0x26FA], [0x26FD, 0x26FD], [0x2705, 0x2705], [0x270A, 0x270B], [0x2728, 0x2728],
      [0x274C, 0x274C], [0x274E, 0x274E], [0x2753, 0x2755], [0x2757, 0x2757], [0x2795, 0x2797],
      [0x27B0, 0x27B0], [0x27BF, 0x27BF], [0x2B1B, 0x2B1C], [0x2B50, 0x2B50], [0x2B55, 0x2B55],
      [0x2E80, 0x303E], [0x3041, 0x33FF], [0x3400, 0x4DBF], [0x4E00, 0x9FFF], [0xA000, 0xA4CF],
      [0xA960, 0xA97F], [0xAC00, 0xD7A3], [0xF900, 0xFAFF], [0xFE10, 0xFE19], [0xFE30, 0xFE6F],
      [0xFF00, 0xFF60], [0xFFE0, 0xFFE6], [0x16FE0, 0x16FE4], [0x17000, 0x18AFF], [0x1B000, 0x1B2FF],
      [0x1F004, 0x1F004], [0x1F0CF, 0x1F0CF], [0x1F18E, 0x1F18E], [0x1F191, 0x1F19A],
      [0x1F200, 0x1F202], [0x1F210, 0x1F23B], [0x1F240, 0x1F248], [0x1F250, 0x1F251],
      [0x1F260, 0x1F265], [0x1F300, 0x1F320], [0x1F32D, 0x1F335], [0x1F337, 0x1F37C],
      [0x1F37E, 0x1F393], [0x1F3A0, 0x1F3CA], [0x1F3CF, 0x1F3D3], [0x1F3E0, 0x1F3F0],
      [0x1F3F4, 0x1F3F4], [0x1F3F8, 0x1F43E], [0x1F440, 0x1F440], [0x1F442, 0x1F4FC],
      [0x1F4FF, 0x1F53D], [0x1F54B, 0x1F54E], [0x1F550, 0x1F567], [0x1F57A, 0x1F57A],
      [0x1F595, 0x1F596], [0x1F5A4, 0x1F5A4], [0x1F5FB, 0x1F64F], [0x1F680, 0x1F6C5],
      [0x1F6CC, 0x1F6CC], [0x1F6D0, 0x1F6D2], [0x1F6D5, 0x1F6D7], [0x1F6DC, 0x1F6DF],
      [0x1F6EB, 0x1F6EC], [0x1F6F4, 0x1F6FC], [0x1F7E0, 0x1F7EB], [0x1F7F0, 0x1F7F0],
      [0x1F90C, 0x1F93A], [0x1F93C, 0x1F945], [0x1F947, 0x1F9FF], [0x1FA70, 0x1FAFF],
      [0x20000, 0x2FFFD], [0x30000, 0x3FFFD]
    ].freeze

    ZERO_WIDTH = /\A[\p{Mn}\p{Me}​-‏⁠︀-️\u{E0100}-\u{E01EF}]\z/

    attr_reader :cols, :rows, :title

    def initialize(cols:, rows:)
      @cols = cols
      @rows = rows
      @title = nil
      @style_cache = {}
      @reply = +""
      full_reset
      @state = :ground
      @utf8 = +"".b
      @utf8_need = 0
    end

    def feed(bytes)
      @reply = +""
      bytes.to_s.b.each_byte { |b| step(b) }
      @reply
    end

    def cursor = [@row, @col]
    def cursor_visible? = @cursor_visible
    def alt_screen? = @alt_active

    def modes
      list = @flags.keys
      list << @mouse if TRACKED_MOUSE.include?(@mouse)
      list.sort
    end

    def lines
      @grid.map { |row| row.map { |cell| cell[2].zero? ? "" : cell[0] }.join.sub(/ +\z/, "") }
    end

    def style_runs
      runs = []
      @grid.each_with_index do |row, r|
        start = 0
        cur = nil
        row.each_with_index do |cell, c|
          s = style_string(cell[1])
          next if s == cur

          runs << [r, start, c - 1, cur] if cur && !cur.empty?
          start = c
          cur = s
        end
        runs << [r, start, @cols - 1, cur] if cur && !cur.empty?
      end
      runs
    end

    def snapshot
      w = @rows.to_s.size
      m = modes
      out = ["alt_screen: #{@alt_active ? "on" : "off"}  cursor: #{@cursor_visible ? "visible" : "hidden"}  " \
             "modes: #{m.empty? ? "-" : m.join(" ")}"]
      lines.each_with_index { |line, i| out << "#{(i + 1).to_s.rjust(w)}|#{line}" }
      runs = style_runs
      if runs.empty?
        out << "styles: none"
      else
        out << "styles:"
        runs.each { |r, a, b, s| out << "#{(r + 1).to_s.rjust(w)}:#{a + 1}-#{b + 1} #{s}" }
      end
      "#{out.join("\n")}\n"
    end

    private

    # ---- state -------------------------------------------------------------

    def full_reset
      @pen = DEFAULT_PEN
      @main = Array.new(@rows) { blank_row }
      @alt = Array.new(@rows) { blank_row }
      @grid = @main
      @alt_active = false
      @row = 0
      @col = 0
      @wrap_pending = false
      @autowrap = true
      @origin = false
      @insert = false
      @cursor_visible = true
      @flags = {}
      @mouse = nil
      @top = 0
      @bottom = @rows - 1
      @saved = { main: nil, alt: nil }
      @charsets = %i[ascii ascii ascii ascii]
      @gl = 0
      @tabs = Array.new(@cols) { |c| (c % 8).zero? }
      @last_char = nil
    end

    def soft_reset
      @pen = DEFAULT_PEN
      @cursor_visible = true
      @autowrap = true
      @origin = false
      @insert = false
      @top = 0
      @bottom = @rows - 1
      @charsets = %i[ascii ascii ascii ascii]
      @gl = 0
      @saved[slot] = nil
      @wrap_pending = false
    end

    def slot = @alt_active ? :alt : :main

    def blank_pen
      @pen.bg ? Pen.new(attrs: 0, fg: nil, bg: @pen.bg) : DEFAULT_PEN
    end

    def blank_cell(pen = blank_pen) = [" ", pen, 1]

    def blank_row
      pen = blank_pen
      Array.new(@cols) { blank_cell(pen) }
    end

    def style_string(pen)
      @style_cache[pen] ||= begin
        parts = []
        ATTR_NAMES.each_with_index { |name, i| parts << name if pen.attrs[i] == 1 }
        parts << "fg=#{pen.fg}" if pen.fg
        parts << "bg=#{pen.bg}" if pen.bg
        parts.join(" ").freeze
      end
    end

    # ---- parser ------------------------------------------------------------

    def step(b)
      case @state
      when :ground then ground(b)
      when :escape then escape(b)
      when :escape_inter then escape_inter(b)
      when :csi then csi(b)
      when :csi_ignore then csi_ignore(b)
      when :osc then osc(b)
      when :osc_esc then osc_esc(b)
      when :string then string(b)
      when :string_esc then string_esc(b)
      end
    end

    def ground(b)
      if @utf8_need.positive?
        if (b & 0xC0) == 0x80
          @utf8 << b
          @utf8_need -= 1
          finish_utf8 if @utf8_need.zero?
          return
        end
        @utf8_need = 0
        @utf8 = +"".b
        put_char("�")
      end

      if b < 0x20
        control(b)
      elsif b < 0x7F
        ch = b.chr
        ch = DEC_GRAPHICS[b] if @charsets[@gl] == :dec && DEC_GRAPHICS.key?(b)
        put_char(ch)
      elsif b == 0x7F
        nil
      elsif b.between?(0xC2, 0xF4)
        @utf8 = +"".b << b
        @utf8_need = if b >= 0xF0 then 3 elsif b >= 0xE0 then 2 else 1 end
      else
        put_char("�")
      end
    end

    def finish_utf8
      s = @utf8.force_encoding(Encoding::UTF_8)
      @utf8 = +"".b
      return put_char("�") unless s.valid_encoding?
      return if s.ord.between?(0x80, 0x9F)

      put_char(s)
    end

    def control(b)
      case b
      when 0x08 then backspace
      when 0x09 then tab_forward(1)
      when 0x0A, 0x0B, 0x0C then index
      when 0x0D
        @col = 0
        @wrap_pending = false
      when 0x0E then @gl = 1
      when 0x0F then @gl = 0
      when 0x18, 0x1A then @state = :ground
      when 0x1B then start_escape
      end
    end

    def start_escape
      @state = :escape
      @inter = +""
    end

    # C0 controls inside a sequence: CAN/SUB abort, ESC restarts, the rest execute.
    def sequence_control(b)
      case b
      when 0x18, 0x1A then @state = :ground
      when 0x1B then start_escape
      else control(b)
      end
    end

    def escape(b)
      if b < 0x20
        sequence_control(b)
      elsif b < 0x30
        @inter << b
        @state = :escape_inter
      elsif b == 0x5B # [
        @params = +""
        @inter = +""
        @private = nil
        @state = :csi
      elsif b == 0x5D # ]
        @osc = +"".b
        @state = :osc
      elsif [0x50, 0x58, 0x5E, 0x5F].include?(b) # P X ^ _
        @state = :string
      elsif b < 0x7F
        @state = :ground
        esc_dispatch(b, "")
      elsif b > 0x7F
        @state = :ground
      end
    end

    def escape_inter(b)
      if b < 0x20
        sequence_control(b)
      elsif b < 0x30
        @inter << b
      elsif b < 0x7F
        @state = :ground
        esc_dispatch(b, @inter)
      elsif b > 0x7F
        @state = :ground
      end
    end

    def csi(b)
      if b < 0x20
        sequence_control(b)
      elsif b < 0x30
        @inter << b
      elsif b < 0x40
        if !@inter.empty?
          @state = :csi_ignore
        elsif b >= 0x3C && @params.empty? && @private.nil?
          @private = b.chr
        elsif b >= 0x3C
          @state = :csi_ignore
        else
          @params << b
        end
      elsif b < 0x7F
        @state = :ground
        csi_dispatch(b.chr)
      elsif b > 0x7F
        @state = :csi_ignore
      end
    end

    def csi_ignore(b)
      if b < 0x20
        sequence_control(b)
      elsif b.between?(0x40, 0x7E)
        @state = :ground
      end
    end

    def osc(b)
      case b
      when 0x07
        @state = :ground
        osc_dispatch("\a")
      when 0x1B then @state = :osc_esc
      when 0x18, 0x1A then @state = :ground
      else
        @osc << b if b >= 0x20 && @osc.bytesize < 4096
      end
    end

    def osc_esc(b)
      @state = :ground
      osc_dispatch("\e\\")
      return if b == 0x5C

      start_escape
      step(b)
    end

    def string(b)
      case b
      when 0x1B then @state = :string_esc
      when 0x18, 0x1A then @state = :ground
      end
    end

    def string_esc(b)
      @state = :ground
      return if b == 0x5C

      start_escape
      step(b)
    end

    # ---- dispatch ----------------------------------------------------------

    def esc_dispatch(final, inter)
      case inter
      when ""
        case final
        when 0x37 then save_cursor # 7
        when 0x38 then restore_cursor # 8
        when 0x44 then index # D
        when 0x45 # E
          @col = 0
          index
        when 0x4D then reverse_index # M
        when 0x63 then full_reset # c
        when 0x48 then @tabs[@col] = true # H
        end
      when "(", ")", "*", "+"
        @charsets["()*+".index(inter)] = final == 0x30 ? :dec : :ascii
      when "#"
        decaln if final == 0x38
      end
    end

    def osc_dispatch(terminator)
      data = @osc.dup.force_encoding(Encoding::UTF_8).scrub("�")
      code, rest = data.split(";", 2)
      case code
      when "0", "2" then @title = rest.to_s
      when "10" then @reply << "\e]10;rgb:ffff/ffff/ffff#{terminator}" if rest == "?"
      when "11" then @reply << "\e]11;rgb:0000/0000/0000#{terminator}" if rest == "?"
      end
    end

    def parse_params
      return [] if @params.empty?

      @params.split(";", -1).map { |p| p.split(":", -1).map { |s| s.empty? ? nil : s.to_i } }
    end

    def csi_dispatch(final)
      params = parse_params
      arg = lambda do |i, default = 1|
        v = params.dig(i, 0)
        v.nil? || v.zero? ? default : v
      end
      raw = params.dig(0, 0) || 0

      if @private == "?"
        if @inter.empty? && (final == "h" || final == "l")
          params.each { |p| dec_mode(p[0], final == "h") if p[0] }
        elsif @inter == "$" && final == "p"
          decrqm(raw)
        end
        return
      end
      return unless @private.nil?

      unless @inter.empty?
        soft_reset if @inter == "!" && final == "p"
        return
      end

      case final
      when "@" then insert_chars(arg.(0))
      when "A" then cursor_up(arg.(0))
      when "B", "e" then cursor_down(arg.(0))
      when "C", "a" then move_to_col(@col + arg.(0))
      when "D" then move_to_col(@col - arg.(0))
      when "E"
        cursor_down(arg.(0))
        @col = 0
      when "F"
        cursor_up(arg.(0))
        @col = 0
      when "G", "`" then move_to_col(arg.(0) - 1)
      when "H", "f"
        set_row(arg.(0) - 1)
        move_to_col(arg.(1) - 1)
      when "I" then tab_forward(arg.(0))
      when "J" then erase_display(raw)
      when "K" then erase_line(raw)
      when "L" then insert_lines(arg.(0))
      when "M" then delete_lines(arg.(0))
      when "P" then delete_chars(arg.(0))
      when "S" then scroll_up(arg.(0))
      when "T" then scroll_down(arg.(0)) if params.size <= 1
      when "X" then erase_chars(arg.(0))
      when "Z" then tab_backward(arg.(0))
      when "b" then repeat(arg.(0))
      when "c" then @reply << "\e[?62;22c" if raw.zero?
      when "d" then set_row(arg.(0) - 1)
      when "g" then clear_tabs(raw)
      when "h", "l" then params.each { |p| @insert = final == "h" if p[0] == 4 }
      when "m" then sgr(params)
      when "n" then dsr(raw)
      when "r" then set_margins(arg.(0), arg.(1, @rows))
      when "s" then save_cursor
      when "u" then restore_cursor
      end
    end

    def dsr(code)
      case code
      when 5 then @reply << "\e[0n"
      when 6
        r = @origin ? @row - @top : @row
        @reply << "\e[#{r + 1};#{@col + 1}R"
      end
    end

    def dec_mode(n, on)
      case n
      when *TRACKED_FLAGS then on ? @flags[n] = true : @flags.delete(n)
      when *MOUSE_MODES then @mouse = on ? n : nil # xterm: one mouse mode at a time
      when 6
        @origin = on
        home
      when 7
        @autowrap = on
        @wrap_pending = false
      when 25 then @cursor_visible = on
      when 47 then switch_screen(on)
      when 1047
        @alt.each_index { |i| @alt[i] = blank_row } if !on && @alt_active
        switch_screen(on)
      when 1048 then on ? save_cursor : restore_cursor
      when 1049
        if on
          save_cursor unless @alt_active
          switch_screen(true)
          @alt.each_index { |i| @alt[i] = blank_row }
        else
          switch_screen(false)
          restore_cursor
        end
      end
    end

    def decrqm(n)
      value =
        case n
        when *TRACKED_FLAGS then @flags[n]
        when *MOUSE_MODES then @mouse == n
        when 6 then @origin
        when 7 then @autowrap
        when 25 then @cursor_visible
        when 47, 1047, 1049 then @alt_active
        end
      state = if value.nil? then 0 elsif value then 1 else 2 end
      @reply << "\e[?#{n};#{state}$y"
    end

    def switch_screen(alt)
      @alt_active = alt
      @grid = alt ? @alt : @main
    end

    # ---- SGR ---------------------------------------------------------------

    def sgr(params)
      params = [[0]] if params.empty?
      attrs = @pen.attrs
      fg = @pen.fg
      bg = @pen.bg
      i = 0
      while i < params.size
        sub = params[i]
        code = sub[0] || 0
        case code
        when 0
          attrs = 0
          fg = bg = nil
        when 1 then attrs |= BOLD
        when 2 then attrs |= FAINT
        when 3 then attrs |= ITALIC
        when 4
          if sub.size > 1 && (sub[1] || 0).zero?
            attrs &= ~UNDERLINE
          else
            attrs |= UNDERLINE
          end
        when 5 then attrs |= BLINK
        when 7 then attrs |= REVERSE
        when 8 then attrs |= INVISIBLE
        when 9 then attrs |= STRIKE
        when 21 then attrs |= UNDERLINE
        when 22 then attrs &= ~(BOLD | FAINT)
        when 23 then attrs &= ~ITALIC
        when 24 then attrs &= ~UNDERLINE
        when 25 then attrs &= ~BLINK
        when 27 then attrs &= ~REVERSE
        when 28 then attrs &= ~INVISIBLE
        when 29 then attrs &= ~STRIKE
        when 30..37 then fg = code - 30
        when 39 then fg = nil
        when 40..47 then bg = code - 40
        when 49 then bg = nil
        when 90..97 then fg = code - 90 + 8
        when 100..107 then bg = code - 100 + 8
        when 38, 48, 58
          color, used = extended_color(params, i)
          i += used
          if color
            fg = color if code == 38
            bg = color if code == 48
          end
        end
        i += 1
      end
      @pen = Pen.new(attrs: attrs, fg: fg, bg: bg)
    end

    # Returns [color or nil, number of extra ;-separated params consumed].
    def extended_color(params, i)
      sub = params[i]
      if sub.size > 1
        case sub[1]
        when 5 then [index_color(sub[2]), 0]
        when 2 then [rgb(*(sub.size >= 6 ? sub[3, 3] : sub[2, 3])), 0]
        else [nil, 0]
        end
      else
        case params.dig(i + 1, 0)
        when 5 then [index_color(params.dig(i + 2, 0)), 2]
        when 2 then [rgb(params.dig(i + 2, 0), params.dig(i + 3, 0), params.dig(i + 4, 0)), 4]
        else [nil, params.size]
        end
      end
    end

    def index_color(n) = n&.between?(0, 255) ? n : nil

    def rgb(r, g, b)
      format("#%02x%02x%02x", *[r, g, b].map { |v| (v || 0).clamp(0, 255) })
    end

    # ---- printing ----------------------------------------------------------

    def width_of(ch)
      cp = ch.ord
      return 1 if cp < 0x300
      return 0 if ch.match?(ZERO_WIDTH)
      return 1 if cp < 0x1100

      range = WIDE.bsearch { |(_, hi)| hi >= cp }
      range && range[0] <= cp ? 2 : 1
    end

    def put_char(ch)
      w = width_of(ch)
      return combine(ch) if w.zero?

      @last_char = ch
      if @wrap_pending
        @col = 0
        index
      end
      if w == 2 && @col == @cols - 1
        if @autowrap
          @col = 0
          index
        else
          @col = [@cols - 2, 0].max
        end
      end
      insert_chars(w, keep_wrap: true) if @insert
      write_cell(@row, @col, ch, w)
      @col += w
      return unless @col >= @cols

      @col = @cols - 1
      @wrap_pending = @autowrap
    end

    def write_cell(r, c, ch, w)
      row = @grid[r]
      clear_wide_neighbours(row, c)
      clear_wide_neighbours(row, c + 1) if w == 2 && c + 1 < @cols
      row[c] = [ch, @pen, w == 2 && c + 1 < @cols ? 2 : 1]
      row[c + 1] = ["", @pen, 0] if w == 2 && c + 1 < @cols
    end

    # Overwriting half of a wide character blanks its other half.
    def clear_wide_neighbours(row, c)
      cell = row[c]
      if cell[2].zero? && c.positive?
        row[c - 1] = [" ", row[c - 1][1], 1]
        row[c] = [" ", cell[1], 1]
      elsif cell[2] == 2 && c + 1 < @cols
        row[c + 1] = [" ", row[c + 1][1], 1]
      end
    end

    def combine(ch)
      return unless @last_char

      c = @wrap_pending ? @col : @col - 1
      return if c.negative?

      row = @grid[@row]
      c -= 1 if row[c][2].zero? && c.positive?
      cell = row[c]
      row[c] = [cell[0] + ch, cell[1], cell[2]]
    end

    def repeat(n)
      return unless @last_char

      [n, @cols * @rows].min.times { put_char(@last_char) }
    end

    # ---- cursor ------------------------------------------------------------

    def home
      @row = @origin ? @top : 0
      @col = 0
      @wrap_pending = false
    end

    def set_row(r)
      @row = @origin ? (@top + r).clamp(@top, @bottom) : r.clamp(0, @rows - 1)
      @wrap_pending = false
    end

    def move_to_col(c)
      @col = c.clamp(0, @cols - 1)
      @wrap_pending = false
    end

    def cursor_up(n)
      floor = @row >= @top ? @top : 0
      @row = [@row - n, floor].max
      @wrap_pending = false
    end

    def cursor_down(n)
      ceiling = @row <= @bottom ? @bottom : @rows - 1
      @row = [@row + n, ceiling].min
      @wrap_pending = false
    end

    # xterm (no reverse-wrap): BS from a pending wrap still moves left of the last column.
    def backspace
      @col -= 1 if @col.positive?
      @wrap_pending = false
    end

    def tab_forward(n)
      n.times do
        nxt = (@col + 1...@cols).find { |c| @tabs[c] }
        @col = nxt || @cols - 1
      end
      @wrap_pending = false
    end

    def tab_backward(n)
      n.times do
        prev = (0...@col).reverse_each.find { |c| @tabs[c] }
        @col = prev || 0
      end
      @wrap_pending = false
    end

    def clear_tabs(mode)
      case mode
      when 0 then @tabs[@col] = false
      when 3 then @tabs.fill(false)
      end
    end

    def index
      if @row == @bottom
        scroll_up(1)
      elsif @row < @rows - 1
        @row += 1
      end
      @wrap_pending = false
    end

    def reverse_index
      if @row == @top
        scroll_down(1)
      elsif @row.positive?
        @row -= 1
      end
      @wrap_pending = false
    end

    def save_cursor
      @saved[slot] = {
        row: @row, col: @col, pen: @pen, wrap: @wrap_pending, origin: @origin,
        charsets: @charsets.dup, gl: @gl
      }
    end

    def restore_cursor
      s = @saved[slot]
      unless s
        @pen = DEFAULT_PEN
        @origin = false
        @charsets = %i[ascii ascii ascii ascii]
        @gl = 0
        home
        return
      end
      @row = s[:row].clamp(0, @rows - 1)
      @col = s[:col].clamp(0, @cols - 1)
      @pen = s[:pen]
      @wrap_pending = s[:wrap]
      @origin = s[:origin]
      @charsets = s[:charsets].dup
      @gl = s[:gl]
    end

    def set_margins(top, bottom)
      bottom = [bottom, @rows].min
      return unless top < bottom

      @top = top - 1
      @bottom = bottom - 1
      home
    end

    # ---- editing -----------------------------------------------------------

    def erase_cells(r, c0, c1)
      return if c0 > c1

      row = @grid[r]
      clear_wide_neighbours(row, c0)
      clear_wide_neighbours(row, c1) if c1 + 1 < @cols && row[c1 + 1][2].zero?
      pen = blank_pen
      (c0..c1).each { |c| row[c] = blank_cell(pen) }
    end

    def erase_display(mode)
      case mode
      when 0
        erase_cells(@row, @col, @cols - 1)
        (@row + 1...@rows).each { |r| @grid[r] = blank_row }
      when 1
        (0...@row).each { |r| @grid[r] = blank_row }
        erase_cells(@row, 0, @col)
      when 2
        @grid.each_index { |r| @grid[r] = blank_row }
      end
      @wrap_pending = false
    end

    def erase_line(mode)
      case mode
      when 0 then erase_cells(@row, @col, @cols - 1)
      when 1 then erase_cells(@row, 0, @col)
      when 2 then erase_cells(@row, 0, @cols - 1)
      end
      @wrap_pending = false
    end

    def erase_chars(n)
      erase_cells(@row, @col, [@col + n - 1, @cols - 1].min)
      @wrap_pending = false
    end

    def insert_chars(n, keep_wrap: false)
      row = @grid[@row]
      n = [n, @cols - @col].min
      clear_wide_neighbours(row, @col)
      pen = blank_pen
      row.insert(@col, *Array.new(n) { blank_cell(pen) })
      row.slice!(@cols..)
      row[@cols - 1] = [" ", row[@cols - 1][1], 1] if row[@cols - 1][2] == 2
      @wrap_pending = false unless keep_wrap
    end

    def delete_chars(n)
      row = @grid[@row]
      n = [n, @cols - @col].min
      clear_wide_neighbours(row, @col)
      clear_wide_neighbours(row, @col + n) if @col + n < @cols && row[@col + n][2].zero?
      row.slice!(@col, n)
      pen = blank_pen
      n.times { row << blank_cell(pen) }
      @wrap_pending = false
    end

    def insert_lines(n)
      return unless @row.between?(@top, @bottom)

      n = [n, @bottom - @row + 1].min
      n.times do
        @grid.delete_at(@bottom)
        @grid.insert(@row, blank_row)
      end
      @col = 0
      @wrap_pending = false
    end

    def delete_lines(n)
      return unless @row.between?(@top, @bottom)

      n = [n, @bottom - @row + 1].min
      n.times do
        @grid.delete_at(@row)
        @grid.insert(@bottom, blank_row)
      end
      @col = 0
      @wrap_pending = false
    end

    def scroll_up(n)
      [n, @bottom - @top + 1].min.times do
        @grid.delete_at(@top)
        @grid.insert(@bottom, blank_row)
      end
    end

    def scroll_down(n)
      [n, @bottom - @top + 1].min.times do
        @grid.delete_at(@bottom)
        @grid.insert(@top, blank_row)
      end
    end

    def decaln
      @grid.each_index { |r| @grid[r] = Array.new(@cols) { ["E", DEFAULT_PEN, 1] } }
      @top = 0
      @bottom = @rows - 1
      @origin = false
      home
    end
  end
end
