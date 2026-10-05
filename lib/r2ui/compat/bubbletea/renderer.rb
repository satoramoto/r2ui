# frozen_string_literal: true

require_relative "ansi"

module R2UI
  module Compat
    module Tea
      # Port of the bubbletea 0.1.4 gem's Go renderer (go/renderer.go):
      # redraws the whole view in place, line by line, erasing what each line
      # leaves behind. Writes each frame with one write followed by a flush.
      #
      # r2ui addition: with `synchronized` on, each frame is wrapped in DEC mode 2026 (synchronized
      # output), so the terminal paints it at once. Off by default, as upstream.
      class Renderer
        SYNC_BEGIN = "\e[?2026h"
        SYNC_END = "\e[?2026l"

        def initialize(output, synchronized: false)
          @output = output
          @synchronized = synchronized ? true : false
          @mutex = Mutex.new
          @last_render = "".b
          @last_lines = []
          @lines_rendered = 0
          @width = 0
          @height = 0
          @alt_screen = false
        end

        def set_size(width, height)
          width = Integer(width)
          height = Integer(height)
          @mutex.synchronize do
            @width = width
            @height = height
          end
        end

        def alt_screen=(enabled)
          @mutex.synchronize { @alt_screen = enabled ? true : false }
        end

        def synchronized=(enabled)
          @mutex.synchronize { @synchronized = enabled ? true : false }
        end

        def render(view)
          view = c_string(view)

          @mutex.synchronize do
            return if view == @last_render

            new_lines = view.empty? ? ["".b] : view.split("\n", -1)
            new_lines = new_lines.last(@height) if @height.positive? && new_lines.length > @height

            buffer = +"".b
            buffer << SYNC_BEGIN if @synchronized
            buffer << ANSI::CURSOR_HOME_POSITION if @alt_screen
            if !@alt_screen && @lines_rendered > 1
              buffer << cursor_up(@lines_rendered - 1)
            end
            buffer << "\r" unless @alt_screen

            new_lines.each_with_index do |line, i|
              if @width.positive? && ANSI.string_width(line) > @width
                line = ANSI.truncate(line, @width, "").b
              end
              buffer << line << erase_line(0)
              buffer << "\r\n" if i < new_lines.length - 1
            end

            if new_lines.length < @lines_rendered
              (new_lines.length...@lines_rendered).each do
                buffer << "\r\n" << erase_line(2)
              end
              buffer << cursor_up(@lines_rendered - new_lines.length) unless @alt_screen
            end
            buffer << "\r" unless @alt_screen
            buffer << SYNC_END if @synchronized

            emit(buffer)

            @last_render = view
            @last_lines = new_lines
            @lines_rendered = new_lines.length
          end
          nil
        end

        def clear
          @mutex.synchronize do
            emit(ANSI::ERASE_ENTIRE_SCREEN + ANSI::CURSOR_HOME_POSITION)
            @last_render = "".b
            @last_lines = []
            @lines_rendered = 0
          end
          nil
        end

        private

        # The C glue passes the view through StringValueCStr.
        def c_string(view)
          unless view.is_a?(String)
            raise TypeError, "no implicit conversion of #{view.class} into String" unless view.respond_to?(:to_str)

            view = view.to_str
          end
          raise ArgumentError, "string contains null byte" if view.include?("\0")

          view.b
        end

        # x/ansi CursorUp: CSI A for 1, CSI n A otherwise.
        def cursor_up(n)
          "\e[#{n > 1 ? n : ""}A"
        end

        # x/ansi EraseLine: CSI K for 0, CSI n K otherwise.
        def erase_line(n)
          "\e[#{n.positive? ? n : ""}K"
        end

        # Upstream ignores stdout write errors, so a hangup (EIO/EPIPE) or a
        # closed stream doesn't raise into the program; see Terminal.write.
        def emit(bytes)
          @output.write(bytes)
          @output.flush
        rescue IOError, SystemCallError
          nil
        end
      end
    end
  end
end
