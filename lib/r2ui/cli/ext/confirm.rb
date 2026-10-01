# frozen_string_literal: true

# c03-confirm: a yes/no question.
#
#   confirm("Deploy api to production?")                 # => true / false
#   confirm("Overwrite config?", default: true)
#   confirm("Deploy?") or abort!("cancelled")
#
# On a terminal (Shell#interactive?) it asks inline, like gum confirm:
#
#   ? Deploy api to production?    Yes  › No      ←/→ (h/l, tab) move, enter picks, y/n answer
#
# and leaves "✔ Deploy api to production? · Yes" in the scrollback. ctrl+c or esc raises
# Interrupt (a command exits 130) after the terminal is restored.
#
# Off a terminal it reads one line: "y", "yes", "n", "no" (any case); an empty line or end of
# input means `default:`. When a person can still type (stdin is a terminal, stdout piped) it asks
# "Deploy? [y/N] " on stderr and asks again after an answer it can't read; from a pipe (`yes |
# tool`, CI) it doesn't ask, records "✔ Deploy? · yes" on stderr, and an unreadable answer is an
# error.
#
# This is the reference extension for prompts (docs/cli.md): a Prompt::Model run inline on the
# terminal, a line-reading fallback off it. Copy its shape and its test.
module R2UI
  module CLI
    module Ext
      module Confirm
        YES = %w[y yes true].freeze
        NO = %w[n no false].freeze

        # The inline prompt: a Bubbletea model on R2UI::CLI::Prompt.
        class Model < Prompt::Model
          attr_reader :question, :choice

          def initialize(shell, question, default)
            super(shell)
            @question = question
            @choice = default ? true : false
          end

          def view
            return "#{shell.symbol(:error)} #{question}" if interrupted?
            return Confirm.answered(shell, question, value) if done?

            "#{shell.paint("?", :accent)} #{question}  #{option("Yes", choice)}  #{option("No", !choice)}"
          end

          private

          def key(name, _message)
            case name
            when "y", "Y" then submit(true)
            when "n", "N" then submit(false)
            when "enter" then submit(choice)
            when "left", "right", "h", "l", "tab", "shift+tab"
              @choice = !@choice
              nil
            end
          end

          # The pointer marks the choice without colour too (NO_COLOR on a terminal).
          def option(label, selected)
            selected ? shell.paint("#{shell.theme.symbol(:pointer)} #{label}", :highlight) : shell.paint("  #{label}", :muted)
          end
        end

        module_function

        def answered(shell, question, value)
          "#{shell.symbol(:success)} #{question} #{shell.paint("·", :muted)} #{shell.paint(value ? "Yes" : "No", :accent)}"
        end

        # true / false for a typed answer; `default` for none; nil for one it can't read.
        def parse(line, default)
          answer = line.to_s.strip.downcase
          return default if answer.empty?
          return true if YES.include?(answer)

          false if NO.include?(answer)
        end

        def ask_line(shell, question, default)
          hint = default ? "[Y/n]" : "[y/N]"
          loop do
            line = Prompt.read_line(shell, "#{question} #{hint} ")
            value = parse(line, default)
            unless value.nil?
              shell.err_puts("#{shell.symbol(:success)} #{question} · #{value ? "yes" : "no"}") unless shell.input_tty?
              return value
            end
            raise Error, "expected yes or no for #{question.inspect}, got #{line.strip.inspect}" unless shell.input_tty?

            shell.err_puts("Please answer yes or no.")
          end
        end
      end
    end

    extension :confirm do
      helpers do
        def confirm(question, default: false)
          default = default ? true : false
          return Ext::Confirm.ask_line(shell, question, default) unless shell.interactive?

          Prompt.run(shell, Ext::Confirm::Model.new(shell, question, default)).value
        end
      end
    end
  end
end
