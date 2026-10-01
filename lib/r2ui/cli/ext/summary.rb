# frozen_string_literal: true

# c15-summary: a header line to open a run and an npm-style closing line that says how long it
# took.
#
#   heading "deployer v1.4.0"            # bold line, then a blank line
#   tasks { ... }
#   done "Deployed 3 apps"               # ✔ Deployed 3 apps in 4.2s
#   done                                 # Done in 4.2s   (pnpm's closing line)
#
# On a terminal the heading is bold, the ✔ green and " in 4.2s" muted. Off a terminal (pipe, CI)
# the same text with no escape codes. Both write to stdout; inside a live region (`tasks`, ...)
# they print above it.
#
# The time counts from the start of the command (just after its argv is parsed; each run starts
# its own clock). In a script that includes R2UI::CLI::Helpers it counts from when `r2ui/cli`
# was loaded, so everything the script did before its first helper call is in it too. The format
# is the task list's: "120ms", "4.2s", "1m 15s".
module R2UI
  module CLI
    module Ext
      module Summary
        LOADED_AT = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        # When the command running on each shell started (shells a command never ran on use
        # LOADED_AT).
        @started = ObjectSpace::WeakMap.new

        module_function

        def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        def start(shell)
          @started[shell] = now
        end

        def elapsed(shell) = now - (@started[shell] || LOADED_AT)
      end
    end

    extension :summary do
      after_parse { Ext::Summary.start(shell) }

      helpers do
        def heading(text)
          shell.puts(shell.paint(text, :heading))
          shell.puts
          nil
        end

        def done(message = nil)
          time = Ext::Tasks.duration(Ext::Summary.elapsed(shell))
          if message.nil?
            shell.puts("Done#{shell.paint(" in #{time}", :muted)}")
          else
            shell.puts("#{shell.symbol(:success)} #{message}#{shell.paint(" in #{time}", :muted)}")
          end
          nil
        end
      end
    end
  end
end
