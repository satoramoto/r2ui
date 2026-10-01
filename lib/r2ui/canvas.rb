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
  class Canvas
    STYLES = {
      plain: "0", bold: "1", dim: "2", reverse: "7",
      title: "1;36", header: "1;37", border: "90", focus: "36", selected: "7;36",
      ok: "32", warn: "33", alert: "31", accent: "35", muted: "90"
    }.freeze

    SGR = /\A\e\[([0-9;:]*)m\z/
    # SGR, any other escape sequence (CSI, OSC, two-byte; dropped), or a run of text.
    TOKEN = /\e\[[0-9;:]*m|\e(?:\[[0-?]*[ -\/]*[@-~]|\][^\a\e]*(?:\a|\e\\)|[@-_])|[^\e]+|\e/

    attr_reader :width, :height

    # `styles` overrides or adds named styles ({ name => "SGR params" }).
    def initialize(width, height, styles: nil)
      @width = width
      @height = height
      @palette = styles ? STYLES.merge(styles) : STYLES
      @chars = Array.new(height) { Array.new(width, " ") }
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
        if (m = part.match(SGR))
          params = m[1]
          sgr = params.empty? || params.match?(/\A0*\z/) ? nil : [sgr, params].compact.join(";")
          next
        end
        next if part.start_with?("\e")

        part.each_char do |ch|
          w = Compat::Tea::ANSI.string_width(ch)
          next if w.zero?
          return used if used + w > limit

          put(x + used, y, ch, sgr || :plain)
          put(x + used + 1, y, "", sgr || :plain) if w == 2
          used += w
        end
      end
      used
    end

    def write(x, y, text, style = :plain, max: nil)
      return if y.negative? || y >= height

      limit = [max || width, width - x].min
      text.to_s.each_char.first([limit, 0].max).each_with_index do |ch, i|
        next if (x + i).negative?

        @chars[y][x + i] = ch
        @styles[y][x + i] = style
      end
    end

    def fill(rect, char = " ", style = :plain)
      rect.height.times { |dy| write(rect.x, rect.y + dy, char * rect.width, style) }
    end

    def plain_lines = @chars.map { |row| row.join.rstrip }

    # ANSI for each line, so the terminal can redraw only lines that changed.
    def ansi_lines
      @chars.each_index.map do |y|
        out = +""
        current = nil
        @chars[y].each_with_index do |ch, x|
          style = @styles[y][x]
          out << "\e[0;#{style.is_a?(String) ? style : @palette.fetch(style)}m" if style != current
          current = style
          out << ch
        end
        out << "\e[0m"
      end
    end

    private

    def put(x, y, ch, style)
      return if x.negative? || x >= width

      @chars[y][x] = ch
      @styles[y][x] = style
    end
  end
end
