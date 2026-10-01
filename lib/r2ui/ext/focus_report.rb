# frozen_string_literal: true

# s16-focus-report: terminal focus in/out (Bubbletea's report_focus, FocusMessage, BlurMessage).
#
#   R2UI.dashboard do
#     report_focus                          # ask the terminal to report focus changes
#     on_blur  { state[:paused] = true }    # the terminal window lost focus
#     on_focus { state[:paused] = false }   # ... and got it back
#
#     row do
#       panel :status, resource: nil do
#         view { state[:terminal_focused] ? "watching" : "paused" }
#       end
#     end
#   end
#
# `state[:terminal_focused]` tracks the terminal's focus: true at start, false after a blur, true
# again after a focus. `on_focus` / `on_blur` blocks run on the update thread (a Context) in the
# order they were declared, after the state is updated; a command they return or enqueue runs.
# Declaring `on_focus` or `on_blur` turns focus reporting on as well (without it they would never
# fire). The runner turns reporting off again on exit.
module R2UI
  module Ext
    module FocusReport
      module_function

      # Whether the dashboard uses focus reporting at all.
      def enabled?(dashboard) = %i[report_focus on_focus on_blur].any? { |k| dashboard.declared(k).any? }
    end
  end

  extension :focus_report do
    dsl :dashboard do
      def report_focus = declare(:report_focus, true)

      def on_focus(&block)
        raise ArgumentError, "on_focus needs a block" unless block

        declare(:on_focus, block)
      end

      def on_blur(&block)
        raise ArgumentError, "on_blur needs a block" unless block

        declare(:on_blur, block)
      end
    end

    setup do
      state[:terminal_focused] = true if Ext::FocusReport.enabled?(dashboard) && !state.key?(:terminal_focused)
    end

    program_options { { report_focus: true } if Ext::FocusReport.enabled?(dashboard) }

    observe(Bubbletea::FocusMessage) { state[:terminal_focused] = true if Ext::FocusReport.enabled?(dashboard) }
    observe(Bubbletea::BlurMessage) { state[:terminal_focused] = false if Ext::FocusReport.enabled?(dashboard) }

    # `call` enqueues each block's command; return nil so the declared blocks aren't taken as commands.
    on Bubbletea::FocusMessage do
      dashboard.declared(:on_focus).each { |block| call(block) }
      nil
    end

    on Bubbletea::BlurMessage do
      dashboard.declared(:on_blur).each { |block| call(block) }
      nil
    end
  end
end
