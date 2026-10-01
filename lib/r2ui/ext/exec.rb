# frozen_string_literal: true

# s09-exec: run an external program in the foreground (Bubble Tea's ExecProcess).
#
#   R2UI.dashboard do
#     on_key "ctrl+e" do
#       execute(ENV.fetch("EDITOR", "vi"), "notes.md") { |status| flash "editor: #{status.exitstatus}" }
#     end
#   end
#
# `execute(*argv) { |status| }` enqueues a Bubbletea::ExecCommand and returns it. When the runner
# runs it, the terminal is released (mouse off, cursor shown, cooked mode; the alt screen is left if
# the app is in it), the program runs with the app's stdin/stdout/stderr and the app waits for it.
# Then the terminal is taken back (alt screen entered again, the whole frame redrawn) and the block
# runs on the update thread (a Context) with the program's Process::Status. A program that can't be
# started gives a status with exit code 127, like a shell.
#
# The compat runner (upstream bubbletea 0.1.4, copied unchanged) only toggles raw mode, cursor and
# mouse around an ExecCommand; it neither leaves the alt screen nor repaints. Go's Bubble Tea does
# both (ReleaseTerminal / RestoreTerminal), so this extension finds the runner driving the app and
# does them on its Program, which keeps the terminal's mode flags right for the cleanup at exit.
module R2UI
  module Ext
    module Exec
      # The message the runner delivers once the program has exited.
      class Done < Bubbletea::Message
        attr_reader :app, :block, :status

        def initialize(app:, block:)
          super()
          @app = app
          @block = block
          @status = nil
        end

        def finish(status) = @status = status
      end

      module_function

      # The ExecCommand that runs `argv` for `app`, then delivers a Done for `block`.
      def command(app, argv, block)
        done = Done.new(app:, block:)
        Bubbletea.exec(-> { done.finish(run(app, argv)) }, message: done)
      end

      # Runs `argv` in the foreground with the terminal released; returns its Process::Status.
      def run(app, argv)
        terminal = Terminal.find(app)
        terminal&.release
        system(*argv)
        $?
      ensure
        terminal&.restore
      end

      # The runner's Program and renderer for one app, for leaving and re-entering the alt screen.
      class Terminal
        def self.find(app)
          runner = ObjectSpace.each_object(Bubbletea::Runner).find do |r|
            r.instance_variable_get(:@model).equal?(app)
          end
          runner && new(runner)
        end

        def initialize(runner)
          @runner = runner
          @program = runner.instance_variable_get(:@program)
          @renderer_id = runner.instance_variable_get(:@renderer_id)
        end

        def release
          @alt_screen = @runner.instance_variable_get(:@in_alt_screen)
          @program.exit_alt_screen if @alt_screen
        end

        # Re-enters the alt screen (which clears it) and makes the next frame draw in full.
        def restore
          @program.enter_alt_screen if @alt_screen
          repaint
        end

        private

        # Go's repaint + resetLinesRendered: forget the last frame so the next one is drawn whole,
        # below the program's output when inline.
        def repaint
          renderer = @renderer_id && defined?(R2UI::Compat::Tea) && R2UI::Compat::Tea.renderer(@renderer_id)
          return unless renderer

          renderer.instance_variable_get(:@mutex).synchronize do
            renderer.instance_variable_set(:@last_render, "".b)
            renderer.instance_variable_set(:@last_lines, [])
            renderer.instance_variable_set(:@lines_rendered, 0)
          end
        end
      end
    end
  end

  extension :exec do
    helpers do
      def execute(*argv, &block)
        raise ArgumentError, "execute needs a program" if argv.empty?

        command(Ext::Exec.command(app, argv.map(&:to_s), block))
      end
    end

    on Ext::Exec::Done do |done|
      pass unless done.app.equal?(app)

      call(done.block, done.status) if done.block
    end
  end
end
