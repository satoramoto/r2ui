# frozen_string_literal: true

# s10-suspend: ctrl+z suspend / resume (Bubbletea's SuspendCommand and ResumeMessage).
#
#   R2UI.dashboard do
#     suspendable                     # ctrl+z suspends the app, like a shell job
#     on_resume { flash "welcome back" }
#
#     on_key "ctrl+s" do suspend end  # or suspend from any block with the `suspend` helper
#   end
#
# Suspending gives the terminal back (raw mode off, cursor shown, mouse off) and stops the process
# with SIGTSTP; `fg` (SIGCONT) takes the terminal again and delivers a Bubbletea::ResumeMessage,
# which runs every `on_resume` block in order on the update thread (a Context: state, flash, a
# returned command runs too). ctrl+z is an ordinary binding (priority 0), so it does nothing on a
# dashboard that isn't `suspendable`.
module R2UI
  module Ext
    module Suspend
      module_function

      def ctrl_z?(message) = message.is_a?(Bubbletea::KeyMessage) && Keys.name(message) == :"ctrl+z"
    end
  end

  extension :suspend do
    dsl :dashboard do
      def suspendable = declare(:suspendable, true)

      def on_resume(&block)
        raise ArgumentError, "on_resume needs a block" unless block

        declare(:on_resume, block)
      end
    end

    helpers do
      # Suspends the program (Bubbletea.suspend); a ResumeMessage arrives when it's resumed.
      def suspend = command(Bubbletea.suspend)
    end

    on(->(msg) { Ext::Suspend.ctrl_z?(msg) }) do
      pass if dashboard.declared(:suspendable).empty?

      suspend
    end

    on Bubbletea::ResumeMessage do
      blocks = dashboard.declared(:on_resume)
      pass if blocks.empty?

      blocks.each { |block| call(block) }
    end
  end
end
