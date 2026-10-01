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
      #
      # - ctrl+c and esc cancel (Prompt.run then raises Interrupt), before anything else sees them.
      # - Other keys go to `key(name, msg)`; return `submit(value)` to answer, or nil to pass the
      #   key on to the hosted component.
      # - `self.component = Bubbles::TextInput.new` hosts a bubbles model: its `init` runs with the
      #   prompt's, and it gets every message the prompt doesn't handle (keys `key` passes on, blink
      #   and other ticks, window size), its commands going out with the prompt's.
      # Subclasses implement `view` (and usually `key`).
      class Model
        include Bubbletea::Model

        attr_reader :value, :shell
        attr_accessor :component

        def initialize(shell)
          @shell = shell
          @done = false
          @interrupted = false
          @component = nil
        end

        def init
          return [self, nil] unless component.respond_to?(:init)

          [self, adopt(component.init)]
        end

        def update(message)
          if message.is_a?(Bubbletea::KeyMessage)
            name = message.to_s
            return cancel if %w[ctrl+c esc].include?(name)

            result = key(name, message)
            return result if result
          end
          forward(message)
        end

        def done? = @done

        def interrupted? = @interrupted

        private

        # Prompts that only use a component may leave this out.
        def key(_name, _message) = nil

        # Sends a message to the hosted component; keeps the model it returns.
        def forward(message)
          return [self, nil] unless component

          [self, adopt(component.update(message))]
        end

        # [model, cmd] or a bare cmd from a component's init/update → the cmd, keeping the model.
        def adopt(result)
          if result.is_a?(Array) && result.size == 2 && !result.first.is_a?(Bubbletea::Command)
            @component = result.first unless result.first.nil?
            result.last
          else
            result
          end
        end

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
