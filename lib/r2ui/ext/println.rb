# frozen_string_literal: true

# s11-println: print a line above the program (Bubbletea's `puts` command).
#
#   R2UI.dashboard do
#     every 60 do
#       println "#{Time.now.strftime("%H:%M")} checked #{state[:count].to_i} deploys"
#     end
#   end
#
# `println(text)` enqueues `Bubbletea.puts(text)` and returns that command, so a block may also
# just end with it. In inline mode (no alt screen) the line is printed above the program's view
# and stays in the terminal's scrollback; the runner handles it exactly as it handles
# `Bubbletea.puts` returned from a plain Bubbletea model. Each call prints its own line, in call order. Available in every handler and user block.
module R2UI
  extension :println do
    helpers do
      def println(text) = command(Bubbletea.puts(text))
    end
  end
end
