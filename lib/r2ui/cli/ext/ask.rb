# frozen_string_literal: true

# c17-ask: a line of text.
#
#   name = ask("Project name?")                                   # => "my-app"
#   name = ask("Project name?", default: "app")                   # enter alone → "app"
#   name = ask("Project name?", placeholder: "my-app",
#              validate: ->(v) { "too short" if v.size < 2 })     # a String is the error message
#
# On a terminal (Shell#interactive?) it hosts bubbles' TextInput inline, like gum input:
#
#   ? Project name? › my-app▌                    the default (or `placeholder:`) shows muted
#     ✖ too short                                 until something valid is typed
#
# enter submits (the default when nothing is typed); an answer `validate:` rejects keeps the prompt
# open with its message under the field until the text is fixed. It leaves
# "✔ Project name? · my-app" in the scrollback. ctrl+c or esc raises Interrupt (a command exits
# 130) after the terminal is restored. Answers are stripped of surrounding spaces.
#
# Off a terminal it reads one line; an empty line or end of input means `default:`. When a person
# can still type (stdin is a terminal, stdout piped) it asks "Project name? (app) " on stderr and
# asks again after an answer `validate:` rejects. From a pipe (`echo web | tool`, CI) it doesn't
# ask, records "✔ Project name? · web" on stderr, and a rejected answer is an error. End of input
# with no default raises a CLI::Error naming the question.
module R2UI
  module CLI
    module Ext
      module Ask
        # The inline prompt: bubbles' TextInput hosted on a Prompt::Model.
        class Model < Prompt::Model
          attr_reader :question, :default, :message

          def initialize(shell, question, default: nil, placeholder: nil, validate: nil)
            super(shell)
            CLI.require_bubbles!
            @question = question
            @default = default
            @validate = validate
            @message = nil
            input = Bubbles::TextInput.new
            input.prompt = ""
            input.placeholder = (placeholder || default).to_s
            input.placeholder_style = shell.color? ? shell.theme.style(:muted) : Lipgloss::Style.new
            input.width = [shell.width - Lipgloss.width(question) - 6, 10].max
            @focus_command = input.focus
            self.component = input
          end

          def init = [self, @focus_command]

          # Re-checks after every edit once a message shows, so it goes away when the text is fixed.
          def update(message)
            result = super
            @message = Ask.check(@validate, answer) if @message && !done?
            result
          end

          def view
            return "#{shell.symbol(:error)} #{question}" if interrupted?
            return Ask.answered(shell, question, value) if done?

            line = "#{shell.paint("?", :accent)} #{question} #{shell.paint(shell.theme.symbol(:pointer), :muted)} #{component.view}"
            return line unless @message

            "#{line}\n  #{shell.paint("#{shell.theme.symbol(:error)} #{@message}", :error)}"
          end

          private

          def key(name, _message)
            return nil unless name == "enter"

            value = answer
            @message = Ask.check(@validate, value)
            return [self, nil] if @message

            submit(value)
          end

          # What enter would submit now.
          def answer
            text = component.value.strip
            text.empty? && !default.nil? ? default.to_s : text
          end
        end

        module_function

        def answered(shell, question, value)
          "#{shell.symbol(:success)} #{question} #{shell.paint("·", :muted)} #{shell.paint(value, :accent)}"
        end

        # The validation message for `value`, or nil when it's fine (or there is no validator).
        def check(validate, value)
          return nil unless validate

          result = validate.call(value)
          result.is_a?(String) && !result.empty? ? result : nil
        end

        def ask_line(shell, question, default, validate)
          hint = default.nil? || default.to_s.empty? ? "" : " (#{default})"
          loop do
            line = Prompt.read_line(shell, "#{question}#{hint} ")
            raise Error, "no answer for #{question.inspect} (end of input); pass it as a command-line option, or run in a terminal" if line.nil? && default.nil?

            value = line.to_s.strip
            value = default.to_s if value.empty? && !default.nil?
            message = check(validate, value)
            if message.nil?
              shell.err_puts("#{shell.symbol(:success)} #{question} · #{value}") unless shell.input_tty?
              return value
            end
            raise Error, "invalid answer for #{question.inspect}: #{message} (got #{value.inspect})" if line.nil? || !shell.input_tty?

            shell.err_puts("#{shell.symbol(:error)} #{message}")
          end
        end
      end
    end

    extension :ask do
      helpers do
        def ask(question, default: nil, placeholder: nil, validate: nil)
          return Ext::Ask.ask_line(shell, question, default, validate) unless shell.interactive?

          model = Ext::Ask::Model.new(shell, question, default:, placeholder:, validate:)
          Prompt.run(shell, model).value
        end
      end
    end
  end
end
