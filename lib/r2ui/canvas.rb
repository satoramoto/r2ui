# frozen_string_literal: true

module R2UI
  Rect = Data.define(:x, :y, :width, :height) do
    def inner = Rect.new(x: x + 1, y: y + 1, width: [width - 2, 0].max, height: [height - 2, 0].max)
    def bottom = y + height
    def empty? = width <= 0 || height <= 0

    # Split off the top `lines` rows: [top, rest].
    def take(lines)
      lines = lines.clamp(0, height)
      [with(height: lines), with(y: y + lines, height: height - lines)]
    end
  end

  # A grid of styled characters. Widgets draw into it; the terminal (or a snapshot) prints it.
  #
  # Cells hold Integer codepoints, so drawing text allocates nothing per character. Text in another
  # encoding, or with invalid bytes, keeps its one-character Strings instead; both append to a line
  # the same way (`String#<<`). The second cell of a wide character holds "" (prints nothing).
  class Canvas
    STYLES = {
      plain: "0", bold: "1", dim: "2", reverse: "7",
      title: "1;36", header: "1;37", border: "90", focus: "36", selected: "7;36",
      ok: "32", warn: "33", alert: "31", accent: "35", muted: "90"
    }.freeze

    SGR = /\A\e\[([0-9;:]*)m\z/
    # SGR, any other escape sequence (CSI, OSC, two-byte; dropped), or a run of text.
    TOKEN = /\e\[[0-9;:]*m|\e(?:\[[0-?]*[ -\/]*[@-~]|\][^\a\e]*(?:\a|\e\\)|[@-_])|[^\e]+|\e/
    RESET = /\A0*\z/

    SPACE = 32
    WIDE_TAIL = ""
    CODEPOINT_ENCODINGS = [Encoding::UTF_8, Encoding::US_ASCII].freeze
    MEMO_LIMIT = 4096

    # Memos of pure functions, shared by every canvas: cell width per codepoint (ANSI.string_width
    # of that one character), and the "\e[0;...m" prefix per SGR String style and per named style
    # of the default palette.
    WIDTHS = {} # rubocop:disable Style/MutableConstant
    STRING_PREFIXES = {} # rubocop:disable Style/MutableConstant
    PALETTE_PREFIXES = {} # rubocop:disable Style/MutableConstant

    def self.cell_width(cp)
      return 1 if cp >= 0x20 && cp < 0x7F

      WIDTHS[cp] ||= Compat::Tea::ANSI.string_width(cp.chr(Encoding::UTF_8))
    end

    attr_reader :width, :height

    # `styles` overrides or adds named styles ({ name => "SGR params" }).
    def initialize(width, height, styles: nil)
      @width = width
      @height = height
      @palette = styles ? STYLES.merge(styles) : STYLES
      @prefixes = styles ? {} : PALETTE_PREFIXES
      @chars = Array.new(height) { Array.new(width, SPACE) }
      @styles = Array.new(height) { Array.new(width, :plain) }
    end

    # Writes one line of styled text (a lipgloss render, a bubbles view): its SGR colours are
    # kept per cell, other escapes dropped. Wide characters take two cells. Returns the cells used.
    def write_ansi(x, y, text, max: nil)
      return 0 if y.negative? || y >= height

      limit = [max || width, width - x].min
      used = 0
      sgr = nil
      text.to_s.scan(TOKEN).each do |part|
        if part.getbyte(0) == 27
          if (m = part.match(SGR))
            params = m[1]
            sgr = params.match?(RESET) ? nil : (sgr ? "#{sgr};#{params}" : params)
          end
          next
        end

        style = sgr || :plain
        if codepoints?(part)
          part.each_codepoint do |cp|
            w = Canvas.cell_width(cp)
            next if w.zero?
            return used if used + w > limit

            put(x + used, y, cp, style)
            put(x + used + 1, y, WIDE_TAIL, style) if w == 2
            used += w
          end
        else
          part.each_char do |ch|
            w = Compat::Tea::ANSI.string_width(ch)
            next if w.zero?
            return used if used + w > limit

            put(x + used, y, ch, style)
            put(x + used + 1, y, WIDE_TAIL, style) if w == 2
            used += w
          end
        end
      end
      used
    end

    def write(x, y, text, style = :plain, max: nil)
      return if y.negative? || y >= height

      count = [[max || width, width - x].min, 0].max.to_i
      return if count.zero?

      chars = @chars[y]
      styles = @styles[y]
      str = text.to_s
      i = 0
      cells = codepoints?(str) ? str.each_codepoint : str.each_char
      cells.each do |cell|
        break if i >= count

        unless (x + i).negative?
          chars[x + i] = cell
          styles[x + i] = style
        end
        i += 1
      end
      nil
    end

    def fill(rect, char = " ", style = :plain)
      rect.height.times { |dy| write(rect.x, rect.y + dy, char * rect.width, style) }
    end

    def plain_lines
      @chars.map do |row|
        line = String.new(capacity: row.size, encoding: Encoding::UTF_8)
        row.each { |cell| line << cell }
        line.rstrip!
        line
      end
    end

    # ANSI for each line, so the terminal can redraw only lines that changed.
    def ansi_lines
      @chars.each_with_index.map do |row, y|
        styles = @styles[y]
        out = String.new(capacity: row.size * 4 + 128, encoding: Encoding::UTF_8)
        current = nil
        x = 0
        n = row.size
        while x < n
          style = styles[x]
          out << prefix(style) if style != current
          current = style
          out << row[x]
          x += 1
        end
        out << "\e[0m"
      end
    end

    private

    # Text whose characters can be stored as Integer codepoints (appending one to a UTF-8 line
    # gives the same bytes as appending the character).
    def codepoints?(str) = CODEPOINT_ENCODINGS.include?(str.encoding) && str.valid_encoding?

    def prefix(style)
      if style.is_a?(String)
        STRING_PREFIXES[style] || memo(STRING_PREFIXES, style, "\e[0;#{style}m")
      else
        @prefixes[style] || memo(@prefixes, style, "\e[0;#{@palette.fetch(style)}m")
      end
    end

    def memo(hash, key, value)
      hash.clear if hash.size >= MEMO_LIMIT
      hash[key] = value.freeze
    end

    def put(x, y, ch, style)
      return if x.negative? || x >= width

      @chars[y][x] = ch
      @styles[y][x] = style
    end
  end
end
