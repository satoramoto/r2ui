# frozen_string_literal: true

require "monitor"

module R2UI
  module CLI
    # An inline region redrawn in place: spinners, task lists, progress bars. It draws with the
    # compat engine's inline renderer (R2UI::Compat::Tea::Renderer, Bubbletea's standard
    # renderer), so lines are redrawn and erased exactly the way an inline Bubbletea program's are,
    # but it takes no raw mode and reads no keys: the work runs on the caller's thread, ctrl+c is an
    # ordinary Interrupt, and typed input stays in the terminal's buffer.
    #
    #   live = Live.new(shell) { |frame| "#{Live.spinner(frame)} Building" }
    #   live.run { build }          # draws at FPS until the block returns, then the last frame stays
    #
    # Off a live terminal (a pipe, TERM=dumb) it draws nothing: `run` just yields and the caller
    # prints its own plain lines (check `live?`). The cursor is hidden while drawing and shown
    # again on every exit path (the block's return, an exception, ctrl+c).
    class Live
      # bubbles' Spinner::MINI_DOT frames, at its 12 fps.
      SPINNER = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze
      FPS = 12
      HIDE_CURSOR = "\e[?25l"
      SHOW_CURSOR = "\e[?25h"
      ERASE_BELOW = "\e[J"

      def self.spinner(frame) = SPINNER[frame % SPINNER.size]

      attr_reader :shell, :frame

      # `view` gets the frame number (it ticks at `fps`) and returns the region's lines.
      def initialize(shell, fps: FPS, &view)
        raise ArgumentError, "Live needs a view block" unless view

        @shell = shell
        @fps = fps
        @view = view
        @lock = Monitor.new
        @frame = 0
        @running = false
        @lines = 0
      end

      def live? = shell.live?

      def running? = @running

      # Draws while the block runs; returns the block's value.
      def run
        start
        yield self
      ensure
        stop
      end

      def start
        return self if @running || !live?

        @running = true
        @renderer = new_renderer
        shell.print(HIDE_CURSOR)
        shell.live = self
        refresh
        @ticker = Thread.new do
          loop do
            sleep(1.0 / @fps)
            @lock.synchronize do
              @frame += 1
              draw
            end
          end
        end
        self
      end

      # Redraws now (call after changing what the view shows, so it doesn't wait for a tick).
      def refresh
        @lock.synchronize { draw if @running }
        self
      end

      # Prints a line above the region; it stays in the scrollback. Shell#puts calls this while
      # the region is drawing.
      def println(text)
        @lock.synchronize do
          erase if @running
          shell.output.write("#{text}\n")
          next unless @running

          @renderer = new_renderer
          draw
        end
        nil
      end

      # Draws the last frame, leaves it in the scrollback and shows the cursor again.
      def stop
        return unless @running

        @ticker&.kill
        @ticker&.join
        @lock.synchronize do
          draw
          @running = false
          shell.live = nil
          shell.output.write("\n#{SHOW_CURSOR}")
          shell.output.flush if shell.output.respond_to?(:flush)
        end
        nil
      end

      private

      def draw
        view = @view.call(@frame).to_s
        @renderer.render(view)
        @lines = [view.empty? ? 1 : view.split("\n", -1).size, shell.height].min
      end

      # Moves to the region's first line and erases it and everything below.
      def erase
        up = @lines - 1
        shell.output.write("#{up.positive? ? "\e[#{up}A" : ""}\r#{ERASE_BELOW}")
      end

      def new_renderer
        Compat::Tea::Renderer.new(shell.output).tap { |r| r.set_size(shell.width, shell.height) }
      end
    end
  end
end
