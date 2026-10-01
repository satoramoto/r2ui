# frozen_string_literal: true

require "io/console"

module R2UI
  module CLI
    # Where a tool talks to the user, and what that place can do. Every helper writes through a
    # Shell, never to $stdout directly, so the same code is gorgeous on a terminal and plain in a
    # pipe, and tests run it on StringIOs.
    #
    #   tty?          stdout is a terminal (or `tty:` says so)
    #   live?         redraw in place: tty? and TERM isn't "dumb"
    #   interactive?  prompts may take keys: stdin and stdout are terminals and TERM isn't
    #                 "dumb" (or `interactive:`)
    #   color?        style output: NO_COLOR unset, and FORCE_COLOR set or tty? (or `color:`)
    #
    # Off a terminal, helpers print one stable line per event (no spinners, no cursor movement,
    # no colour) and prompts fall back to reading a line (docs/cli.md, "On and off a terminal").
    class Shell
      attr_reader :input, :output, :error, :env, :theme
      attr_writer :color

      def initialize(input: $stdin, output: $stdout, error: $stderr, env: ENV, tty: nil,
                     interactive: nil, color: nil, width: nil, theme: Theme.new)
        @input = input
        @output = output
        @error = error
        @env = env
        @tty = tty
        @interactive = interactive
        @color = color
        @width = width
        @theme = theme
        @live = nil
      end

      def tty? = @tty.nil? ? io_tty?(output) : @tty

      def live? = tty? && env["TERM"] != "dumb"

      def interactive?
        return @interactive unless @interactive.nil?

        tty? && input_tty? && env["TERM"] != "dumb"
      end

      # Stdin is a terminal. With stdout piped (`tool | tee log`) prompts ask a line on stderr.
      def input_tty?
        return @interactive unless @interactive.nil?
        return @tty unless @tty.nil?

        io_tty?(input)
      end

      def color?
        return @color unless @color.nil?
        return false if present?(env["NO_COLOR"])
        return true if present?(env["FORCE_COLOR"]) && env["FORCE_COLOR"] != "0"

        live?
      end

      def width
        @width || winsize&.last || positive(env["COLUMNS"]) || 80
      end

      def height = winsize&.first || positive(env["LINES"]) || 24

      # Styles `text` with theme styles (:success, :error, :warn, :info, :accent, :muted, :heading,
      # ...) when color? is on; plain text otherwise. Line by line, so lines keep their widths.
      def paint(text, *styles)
        text = text.to_s
        return text if styles.empty? || !color?

        text.split("\n", -1).map { |line| line.empty? ? line : theme.render(line, styles) }.join("\n")
      end

      # A theme symbol (✔ ✖ ⚠ ℹ ○ –), painted in its own style.
      def symbol(name) = paint(theme.symbol(name), name)

      # Writes a line to stdout. While a Live region is drawing, the line goes above it.
      def puts(text = "")
        text = text.to_s
        if @live
          @live.println(text)
        else
          write(output, text.end_with?("\n") ? text : "#{text}\n")
        end
        nil
      end

      def print(text) = write(output, text.to_s)

      # Writes a line to stderr (warnings, errors, prompts off a terminal).
      def err_puts(text = "")
        text = text.to_s
        if @live && error_shares_terminal?
          @live.println(text)
        else
          write(error, text.end_with?("\n") ? text : "#{text}\n")
        end
        nil
      end

      # The Live region drawing now (set by Live; nil otherwise).
      attr_accessor :live

      private

      def write(io, text)
        io.write(text)
        io.flush if io.respond_to?(:flush)
      end

      def error_shares_terminal? = io_tty?(error) && tty?

      def io_tty?(io) = io.respond_to?(:tty?) && io.tty?

      def winsize
        return nil unless @tty.nil? && output.respond_to?(:winsize) && io_tty?(output)

        rows, cols = output.winsize
        cols.positive? ? [rows, cols] : nil
      rescue SystemCallError, IOError
        nil
      end

      def positive(value)
        n = value.to_i
        n.positive? ? n : nil
      end

      def present?(value) = !value.nil? && !value.empty?
    end

    # Named styles as lipgloss options (the same vocabulary as the dashboard DSL's `theme`), and
    # the status symbols. Colours are ANSI palette numbers, so they follow the user's terminal
    # theme, the way npm's and pnpm's do.
    class Theme
      STYLES = {
        success: { foreground: "2" },
        error: { foreground: "1" },
        warn: { foreground: "3" },
        info: { foreground: "4" },
        accent: { foreground: "6" },
        highlight: { foreground: "5", bold: true },
        muted: { faint: true },
        heading: { bold: true },
        pending: { faint: true },
        skipped: { faint: true },
        running: { foreground: "6" }
      }.freeze

      SYMBOLS = {
        success: "✔",
        error: "✖",
        warn: "⚠",
        info: "ℹ",
        pending: "○",
        skipped: "–",
        pointer: "›",
        bullet: "•"
      }.freeze

      def initialize(styles: {}, symbols: {})
        @styles = STYLES.merge(styles)
        @symbols = SYMBOLS.merge(symbols)
        @cache = {}
      end

      def symbol(name) = @symbols.fetch(name) { raise ArgumentError, "unknown symbol #{name.inspect}" }

      def options(name) = @styles.fetch(name) { raise ArgumentError, "unknown style #{name.inspect}" }

      # A Lipgloss::Style for the named styles merged left to right.
      def style(*names)
        @cache[names] ||= names.map { |n| options(n) }.reduce({}, :merge).reduce(Lipgloss::Style.new) do |style, (key, value)|
          style.public_send(key, value)
        end
      end

      def render(text, names) = style(*names).render(text)
    end
  end
end
