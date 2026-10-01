# frozen_string_literal: true

# c25-dashboard: a command opens an r2ui dashboard.
#
#   command :top do
#     summary "Watch the fleet"
#     run { dashboard :fleet, file: "dashboards.rb" }
#   end
#
# `dashboard(name, file: nil, height: nil)` loads the dashboard DSL (`require "r2ui"`; a CLI
# doesn't load it until a command opens a dashboard), then `file`, which defines the dashboards and
# resources with `R2UI.dashboard` / `R2UI.resource`. A relative `file` is looked up next to the
# Ruby file that calls `dashboard` (like require_relative), then in the working directory. Leave
# `file` out when the tool defines its dashboards itself. `name` is what `R2UI.run` takes: a
# dashboard, a resource shown full screen, or nil for :main / the first one.
#
# On a terminal (Shell#interactive?) it runs `R2UI.run(name)` full screen on the alternate
# screen, exactly as `r2ui dashboards.rb fleet` does, and returns when the user quits (q, or
# ctrl+c); raw mode, the alternate screen and the cursor are restored on every exit path, so the
# command carries on (or exits) with the shell as it was.
#
# Off an interactive shell (a pipe, CI, `tool top > frame.txt`) nothing waits for keys: it prints
# one `R2UI.snapshot` frame as plain text, no escape codes, at the shell's width and height
# (`height:` to choose), the same frame `r2ui --snapshot` draws:
#
#   ╭─ Ship ─────────────────────────────────────────╮
#   │Name                    Status                  │
#   │alpha                   up                      │
#   │beta                    down                    │
#   ╰────────────────────────────────────────────────╯
#
# A missing file, or a name no dashboard or resource has, is an error (exit 1, "✖ message").
module R2UI
  module CLI
    module Ext
      module OpenDashboard
        # Bubbletea's runner on the shell's input and output (the upstream runner always uses the
        # process's stdin/stdout), with the app's own program options (alternate screen, fps, and
        # whatever dashboard extensions add).
        class ShellRunner < Bubbletea::Runner
          def initialize(app, shell)
            super(app, **app.program_options)
            @shell = shell
            @program = Bubbletea::Program.new(input: shell.input, output: shell.output)
          end

          private

          # The runner ends inline runs with `print "\r\n"`: send it to the shell, not $stdout.
          def print(*args) = @shell.output.print(*args)
        end

        module_function

        def load_dsl
          require_relative "../../../r2ui" unless defined?(::R2UI::App)
        end

        # An absolute path as is; a relative one next to the calling file, else the working dir.
        def resolve(file, base_dir)
          path = file.to_s
          candidates = [File.expand_path(path)]
          candidates.unshift(File.expand_path(path, base_dir)) if base_dir && !File.absolute_path?(path)
          found = candidates.find { |c| File.file?(c) }
          found or raise Error, "no dashboard file #{path} (looked for #{candidates.uniq.join(", ")})"
        end

        # R2UI.run(name) on the shell's terminal (R2UI.run itself always uses $stdin/$stdout).
        def run(shell, name)
          return R2UI.run(name) if shell.input.equal?($stdin) && shell.output.equal?($stdout)

          app = R2UI::App.new(R2UI.registry, name)
          begin
            ShellRunner.new(app, shell).run
          ensure
            app.stop
          end
        end

        def snapshot(shell, name, height)
          shell.puts(R2UI.snapshot(name, width: shell.width, height: height || shell.height))
        end
      end
    end

    extension :dashboard do
      helpers do
        def dashboard(name = nil, file: nil, height: nil)
          Ext::OpenDashboard.load_dsl
          if file
            location = caller_locations(1, 1).first
            caller_file = location && (location.absolute_path || location.path)
            load Ext::OpenDashboard.resolve(file, caller_file && File.dirname(File.expand_path(caller_file)))
          end
          if shell.interactive?
            Ext::OpenDashboard.run(shell, name)
          else
            Ext::OpenDashboard.snapshot(shell, name, height)
          end
          nil
        end
      end
    end
  end
end
