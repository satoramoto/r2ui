# frozen_string_literal: true

require "io/console"

# c18-password: hidden input for tokens and passwords.
#
#   token = password("Token?")                           # => "s3cret"
#   pass  = password("New password?", confirm: true)     # asks twice, again on a mismatch
#
# On a terminal (Shell#interactive?) it asks inline with a bubbles TextInput in password echo
# mode, one • per typed character (backspace, ctrl+u, home/end edit as in bubbles):
#
#   ? Token? ••••••█
#
# enter submits and leaves "✔ Token? · ••••••" in the scrollback: always six bullets, so the
# line gives away neither the value nor its length. With `confirm: true` it then asks
# "? Token? (again)"; when the two differ it starts over with "They didn't match. Try again."
# under the input. ctrl+c or esc raises Interrupt (a command exits 130) after the terminal is
# restored.
#
# Off a terminal it reads one line (spaces kept, only the line ending removed):
# - stdin is a terminal, stdout piped (`tool | tee log`): asks "Token? " on stderr and reads with
#   echo off (IO#noecho), so the value never appears on the screen; `confirm: true` asks again
#   ("Token? (again) ") and starts over on a mismatch.
# - from a pipe (`echo "$TOKEN" | tool`, CI): reads silently and records "✔ Token? · ••••••" on
#   stderr; with `confirm: true` it reads a second line and a mismatch is an error.
# End of input is an error naming the question. The value itself is never printed or logged.
module R2UI
  module CLI
    module Ext
      module Password
        MASK = "••••••"
        BULLET = "•"
        AGAIN = "(again)"
        MISMATCH = "They didn't match. Try again."

        # The inline prompt: a TextInput in password echo mode on R2UI::CLI::Prompt::Model.
        class Model < Prompt::Model
          attr_reader :question

          def initialize(shell, question, confirm)
            super(shell)
            @question = question
            @confirm = confirm
            @first = nil
            @mismatch = false
            self.component = Password.input
          end

          def init = [self, component.focus]

          def view
            return "#{shell.symbol(:error)} #{question}" if interrupted?
            return Password.answered(shell, question) if done?

            label = @first.nil? ? question : "#{question} #{shell.paint(AGAIN, :muted)}"
            line = "#{shell.paint("?", :accent)} #{label} #{component.view}"
            @mismatch ? "#{line}\n#{shell.paint("  #{MISMATCH}", :error)}" : line
          end

          private

          def key(name, _message)
            return unless name == "enter"

            entered = component.value
            return submit(entered) unless @confirm
            return ask_again(entered) if @first.nil?
            return submit(entered) if entered == @first

            start_over
          end

          def ask_again(entered)
            @first = entered
            @mismatch = false
            fresh_input
          end

          def start_over
            @first = nil
            @mismatch = true
            fresh_input
          end

          def fresh_input
            self.component = Password.input
            [self, component.focus]
          end
        end

        module_function

        def input
          field = Bubbles::TextInput.new
          field.prompt = ""
          field.echo_mode = Bubbles::TextInput::ECHO_PASSWORD
          field.echo_character = BULLET
          field
        end

        def answered(shell, question)
          "#{shell.symbol(:success)} #{question} #{shell.paint("·", :muted)} #{shell.paint(MASK, :accent)}"
        end

        def ask_line(shell, question, confirm)
          loop do
            value = read_secret(shell, "#{question} ", question)
            break value unless confirm

            again = read_secret(shell, "#{question} #{AGAIN} ", question)
            break value if again == value
            raise Error, "the two answers to #{question.inspect} didn't match" unless shell.input_tty?

            shell.err_puts(MISMATCH)
          end.tap do
            shell.err_puts("#{shell.symbol(:success)} #{question} · #{MASK}") unless shell.input_tty?
          end
        end

        # One line with echo off when a person types it; silently from a pipe.
        def read_secret(shell, prompt, question)
          line =
            if shell.input_tty?
              shell.error.write(prompt)
              shell.error.flush if shell.error.respond_to?(:flush)
              hidden_gets(shell)
            else
              shell.input.gets
            end
          raise Error, "no answer for #{question.inspect}: input ended" if line.nil?

          line.chomp
        end

        # The typed newline isn't echoed with echo off, so end the prompt's line ourselves.
        def hidden_gets(shell)
          return shell.input.gets unless shell.input.respond_to?(:noecho)

          line = shell.input.noecho(&:gets)
          shell.error.write("\n")
          line
        end
      end
    end

    extension :password do
      helpers do
        def password(question, confirm: false)
          return Ext::Password.ask_line(shell, question, confirm) unless shell.interactive?

          CLI.require_bubbles!
          Prompt.run(shell, Ext::Password::Model.new(shell, question, confirm)).value
        end
      end
    end
  end
end
