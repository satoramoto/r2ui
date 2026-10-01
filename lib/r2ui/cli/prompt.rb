# frozen_string_literal: true

module R2UI
  module CLI
    # How prompts run. On an interactive shell a prompt is a small Bubbletea model run inline (no
    # alt screen) on r2ui's engine: raw mode while it asks, its last view (the answered line) left
    # in the scrollback, the terminal restored on every exit path. Prompt stories build their model
    # on Prompt::Model, hosting a bubbles component when one fits (TextInput for ask/password, List
    # for choose; `CLI.require_bubbles!` first).
    #
    # Off a terminal a prompt reads one line instead (`Prompt.read_line`): asking on stderr when a
    # person can still type (stdin is a terminal, stdout piped), silently from a pipe otherwise
    # (`yes | tool`, `echo name | tool`), nil at end of input so the prompt falls back to its default.
    module Prompt
      module_function

      # Runs `model` until it quits; returns the final model. ctrl+c raises Interrupt after the
      # terminal is restored (the model sets `interrupted`).
      def run(shell, model)
        runner = InlineRunner.new(model, shell)
        runner.run
        model = runner.model
        raise Interrupt if model.respond_to?(:interrupted?) && model.interrupted?

        model
      end

      def read_line(shell, prompt)
        if shell.input_tty?
          shell.error.write(prompt)
          shell.error.flush if shell.error.respond_to?(:flush)
        end
        line = shell.input.gets
        line&.chomp
      end

      # Bubbletea's runner on the shell's input and output (the upstream runner always uses the
      # process's stdin/stdout), inline.
      class InlineRunner < Bubbletea::Runner
        attr_reader :model

        def initialize(model, shell)
          super(model, alt_screen: false, fps: 30)
          @shell = shell
          @program = Bubbletea::Program.new(input: shell.input, output: shell.output)
        end

        private

        # The runner ends with `print "\r\n"`: send it to the shell's output, not $stdout.
        def print(*args) = @shell.output.print(*args)
      end

      # A base for prompt models: Bubbletea::Model plus the shared answer/interrupt bookkeeping.
      # Subclasses implement `key(name, msg)` and `view`; call `submit(value)` to answer.
      class Model
        include Bubbletea::Model

        attr_reader :value, :shell

        def initialize(shell)
          @shell = shell
          @done = false
          @interrupted = false
        end

        def init = [self, nil]

        def update(message)
          return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)

          name = message.to_s
          return cancel if %w[ctrl+c esc].include?(name)

          key(name, message) || [self, nil]
        end

        def done? = @done

        def interrupted? = @interrupted

        private

        def submit(value)
          @value = value
          @done = true
          [self, Bubbletea.quit]
        end

        def cancel
          @interrupted = true
          @done = true
          [self, Bubbletea.quit]
        end
      end
    end
  end
end
