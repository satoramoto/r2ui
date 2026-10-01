# frozen_string_literal: true

require "io/console"

module R2UI
  module Compat
    module Tea
      # The terminal half of upstream's Go extension (go/terminal.go): raw mode, mode toggles and
      # size, with the same idempotence flags and the exact bytes charmbracelet/x/ansi v0.8.0 writes.
      # Upstream ignores write errors; so do we. Every write is flushed.
      class Terminal
        SET_ALT_SCREEN = "\e[?1049h"
        RESET_ALT_SCREEN = "\e[?1049l"
        ERASE_ENTIRE_SCREEN = "\e[2J"
        CURSOR_HOME = "\e[H"
        HIDE_CURSOR = "\e[?25l"
        SHOW_CURSOR = "\e[?25h"
        SET_BUTTON_EVENT_MOUSE = "\e[?1002h"
        RESET_BUTTON_EVENT_MOUSE = "\e[?1002l"
        SET_ANY_EVENT_MOUSE = "\e[?1003h"
        RESET_ANY_EVENT_MOUSE = "\e[?1003l"
        SET_SGR_EXT_MOUSE = "\e[?1006h"
        RESET_SGR_EXT_MOUSE = "\e[?1006l"
        SET_BRACKETED_PASTE = "\e[?2004h"
        RESET_BRACKETED_PASTE = "\e[?2004l"
        SET_FOCUS_EVENT = "\e[?1004h"
        RESET_FOCUS_EVENT = "\e[?1004l"

        def self.window_title(title) = "\e]2;#{title}\a"

        def self.write(output, string)
          output.write(string)
          output.flush
          nil
        rescue IOError, SystemCallError
          nil
        end

        # Safety net: terminals left with any mode on are restored at exit, as Go's tea_free_program
        # restores raw mode. Only dirty terminals are held, so a clean one is never written twice.
        @dirty = {}.compare_by_identity
        @lock = Mutex.new
        @hook_installed = false

        class << self
          def track(terminal)
            @lock.synchronize do
              if terminal.dirty?
                @dirty[terminal] = true
                install_hook
              else
                @dirty.delete(terminal)
              end
            end
          end

          def restore_all
            terminals = @lock.synchronize { @dirty.keys }
            terminals.each(&:restore)
          end

          private

          # Installed lazily (on the first dirty terminal) so it runs after any at_exit hook that was
          # running the program, such as a test runner's.
          def install_hook
            return if @hook_installed

            @hook_installed = true
            at_exit { Terminal.restore_all }
          end
        end

        attr_reader :input, :output

        def initialize(input, output)
          @input = input
          @output = output
          @raw_mode = false
          @previous_mode = nil
          @alt_screen = false
          @cursor_hidden = false
          @mouse_enabled = false
          @bracketed_paste = false
          @report_focus = false
        end

        def dirty?
          @raw_mode || @alt_screen || @cursor_hidden || @mouse_enabled || @bracketed_paste || @report_focus
        end

        # Like x/term MakeRaw on the input: true on success or when already raw, false when the input
        # is not a terminal.
        def enter_raw_mode
          return true if @raw_mode

          mode = @input.console_mode
          @input.raw!
          @previous_mode = mode
          @raw_mode = true
          Terminal.track(self)
          true
        rescue StandardError
          false
        end

        def exit_raw_mode
          return true unless @raw_mode

          @input.console_mode = @previous_mode if @previous_mode
          @raw_mode = false
          Terminal.track(self)
          true
        rescue StandardError
          false
        end

        def enter_alt_screen
          return if @alt_screen

          write(SET_ALT_SCREEN + ERASE_ENTIRE_SCREEN + CURSOR_HOME)
          @alt_screen = true
          Terminal.track(self)
          nil
        end

        def exit_alt_screen
          return unless @alt_screen

          write(RESET_ALT_SCREEN)
          @alt_screen = false
          Terminal.track(self)
          nil
        end

        def hide_cursor
          return if @cursor_hidden

          write(HIDE_CURSOR)
          @cursor_hidden = true
          Terminal.track(self)
          nil
        end

        def show_cursor
          return unless @cursor_hidden

          write(SHOW_CURSOR)
          @cursor_hidden = false
          Terminal.track(self)
          nil
        end

        def enable_mouse_cell_motion
          write(SET_BUTTON_EVENT_MOUSE + SET_SGR_EXT_MOUSE)
          @mouse_enabled = true
          Terminal.track(self)
          nil
        end

        def enable_mouse_all_motion
          write(SET_ANY_EVENT_MOUSE + SET_SGR_EXT_MOUSE)
          @mouse_enabled = true
          Terminal.track(self)
          nil
        end

        def disable_mouse
          return unless @mouse_enabled

          write(RESET_BUTTON_EVENT_MOUSE + RESET_ANY_EVENT_MOUSE + RESET_SGR_EXT_MOUSE)
          @mouse_enabled = false
          Terminal.track(self)
          nil
        end

        # Upstream writes paste and focus toggles unconditionally; the flags only feed the exit restore.
        def enable_bracketed_paste
          write(SET_BRACKETED_PASTE)
          @bracketed_paste = true
          Terminal.track(self)
          nil
        end

        def disable_bracketed_paste
          write(RESET_BRACKETED_PASTE)
          @bracketed_paste = false
          Terminal.track(self)
          nil
        end

        def enable_report_focus
          write(SET_FOCUS_EVENT)
          @report_focus = true
          Terminal.track(self)
          nil
        end

        def disable_report_focus
          write(RESET_FOCUS_EVENT)
          @report_focus = false
          Terminal.track(self)
          nil
        end

        # [width, height] of the output (Go asks stdout), or nil when it is not a terminal.
        def size
          rows, cols = @output.winsize
          [cols, rows]
        rescue StandardError
          nil
        end

        # Undo whatever is still on, in the runner's cleanup order. Each step is guarded by its flag.
        def restore
          disable_mouse
          disable_bracketed_paste if @bracketed_paste
          disable_report_focus if @report_focus
          exit_alt_screen
          show_cursor
          exit_raw_mode
        end

        private

        def write(string) = Terminal.write(@output, string)
      end
    end
  end
end
