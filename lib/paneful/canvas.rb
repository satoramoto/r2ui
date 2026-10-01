# frozen_string_literal: true

module Paneful
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

    attr_reader :width, :height

    def initialize(width, height)
      @width = width
      @height = height
      @chars = Array.new(height) { Array.new(width, " ") }
      @styles = Array.new(height) { Array.new(width, :plain) }
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
          out << "\e[0;#{STYLES.fetch(style)}m" if style != current
          current = style
          out << ch
        end
        out << "\e[0m"
      end
    end
  end
end
