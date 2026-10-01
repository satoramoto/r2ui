# frozen_string_literal: true

require "io/console"

module Paneful
  # Raw mode, alternate screen, line-diffed redraws. Always restores the terminal on exit.
  class Terminal
    def initialize(input: $stdin, output: $stdout)
      @in = input
      @out = output
      @previous = []
    end

    def open
      @in.raw!
      @out.write("\e[?1049h\e[?25l\e[2J")
      @out.flush
      yield self
    ensure
      @out.write("\e[0m\e[?25h\e[?1049l")
      @out.flush
      @in.cooked!
    end

    def size
      rows, cols = @out.winsize
      [cols, rows]
    end

    def clear = @previous = []

    def draw(canvas)
      out = +""
      lines = canvas.ansi_lines
      lines.each_with_index do |line, y|
        next if @previous[y] == line

        out << "\e[#{y + 1};1H" << line
      end
      @previous = lines
      @out.write(out)
      @out.flush
    end

    # Key names typed within `timeout` seconds (empty if none).
    def read_keys(timeout)
      return [] unless @in.wait_readable(timeout)

      data = @in.read_nonblock(64, exception: false)
      data.is_a?(String) ? Keys.parse(data) : []
    end
  end
end
