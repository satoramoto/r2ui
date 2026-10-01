# frozen_string_literal: true

# c19-choose: pick one of a list.
#
#   region = choose("Region?", %w[eu us ap], default: "eu")              # => "eu"
#   plan = choose("Plan?", { "Free" => :free, "Pro ($9/mo)" => :pro })     # labels ⇒ values
#
# Choices are an Array (each item is its own label, shown with to_s) or a Hash of label ⇒ value.
# `choose` returns the picked value. `default:` (a value or a label) is where the pointer starts
# and the answer for an empty line or end of input off a terminal.
#
# On a terminal (Shell#interactive?) it asks inline, like gum choose:
#
#   ? Region? ↑/↓ move · enter pick
#     › eu
#       us
#       ap
#
# ↑/↓ (or k/j) move and wrap around, home/end (g/G) jump to the ends, enter picks. More than 10
# choices scroll, with "↑ 3 more" / "↓ 4 more" lines above and below. It leaves
# "✔ Region? · eu" in the scrollback. ctrl+c or esc raises Interrupt (a command exits 130) after
# the terminal is restored.
#
# Off a terminal it reads one line: a label (any case) or its 1-based number. An empty line or
# end of input takes `default:`; without one, end of input is an error naming the question and
# its choices. When a person can still type (stdin is a terminal, stdout piped) it lists the
# choices as "  1) eu" lines on stderr, asks "Region? [eu] " and asks again after an answer it
# can't read; from a pipe (`echo us | tool`, CI) it doesn't ask, records "✔ Region? · us" on
# stderr, and an unknown answer is an error.
module R2UI
  module CLI
    module Ext
      module Choose
        VISIBLE = 10

        Option = Data.define(:label, :value)

        # The inline prompt: a pointer list on R2UI::CLI::Prompt.
        class Model < Prompt::Model
          attr_reader :question, :options, :cursor

          def initialize(shell, question, options, cursor)
            super(shell)
            @question = question
            @options = options
            @cursor = cursor || 0
            @offset = 0
            scroll
          end

          def view
            return "#{shell.symbol(:error)} #{question}" if interrupted?
            return Choose.answered(shell, question, options[@cursor].label) if done?

            lines = ["#{shell.paint("?", :accent)} #{question} #{shell.paint("↑/↓ move · enter pick", :muted)}"]
            lines << more("↑", @offset) if @offset.positive?
            window.each_with_index { |option, i| lines << row(option, @offset + i == @cursor) }
            below = options.size - @offset - window.size
            lines << more("↓", below) if below.positive?
            lines.join("\n")
          end

          private

          def key(name, _message)
            case name
            when "enter" then return submit(options[@cursor].value)
            when "up", "k", "shift+tab" then @cursor = (@cursor - 1) % options.size
            when "down", "j", "tab" then @cursor = (@cursor + 1) % options.size
            when "home", "g", "pgup" then @cursor = name == "pgup" ? [@cursor - VISIBLE, 0].max : 0
            when "end", "G", "pgdown" then @cursor = name == "pgdown" ? [@cursor + VISIBLE, options.size - 1].min : options.size - 1
            else return nil
            end
            scroll
            [self, nil]
          end

          def window = options[@offset, VISIBLE]

          # Keeps the cursor inside the visible window, moving it as little as possible.
          def scroll
            @offset = @cursor if @cursor < @offset
            @offset = @cursor - VISIBLE + 1 if @cursor >= @offset + VISIBLE
          end

          # The pointer marks the choice without colour too (NO_COLOR on a terminal).
          def row(option, selected)
            label = option.label
            selected ? "  #{shell.paint("#{shell.theme.symbol(:pointer)} #{label}", :highlight)}" : "    #{label}"
          end

          def more(arrow, count) = "    #{shell.paint("#{arrow} #{count} more", :muted)}"
        end

        module_function

        # Choices as Options: an Array's items are their own labels, a Hash maps label ⇒ value.
        def options(choices)
          list = choices.is_a?(Hash) ? choices.map { |label, value| Option.new(label.to_s, value) } : choices.map { |c| Option.new(c.to_s, c) }
          raise ArgumentError, "choose needs at least one choice" if list.empty?

          list
        end

        # The index of `default` (a value or a label) in options; nil for no default.
        def default_index(options, default)
          return nil if default.nil?

          options.index { |o| o.value == default } || options.index { |o| o.label == default.to_s } ||
            raise(ArgumentError, "default #{default.inspect} is not one of the choices")
        end

        def answered(shell, question, label)
          "#{shell.symbol(:success)} #{question} #{shell.paint("·", :muted)} #{shell.paint(label, :accent)}"
        end

        # The Option a typed line names (a label, any case, or a 1-based number); nil if none.
        def parse(line, options)
          answer = line.to_s.strip
          return options[answer.to_i - 1] if answer.match?(/\A\d+\z/) && answer.to_i.between?(1, options.size)

          options.find { |o| o.label == answer } || options.find { |o| o.label.casecmp?(answer) }
        end

        def ask_line(shell, question, options, default)
          labels = options.map(&:label).join(", ")
          options.each_with_index { |o, i| shell.err_puts("  #{i + 1}) #{o.label}") } if shell.input_tty?
          hint = default ? "[#{options[default].label}] " : ""
          loop do
            line = Prompt.read_line(shell, "#{question} #{hint}")
            if line.nil? || line.strip.empty?
              option = default && options[default]
              raise Error, "no answer for #{question.inspect} (choose one of: #{labels}); pass it as an option or give a default" if line.nil? && !option
            else
              option = parse(line, options)
              raise Error, "#{line.strip.inspect} is not a choice for #{question.inspect} (choose one of: #{labels})" if !option && !shell.input_tty?
            end
            if option
              shell.err_puts(answered(shell, question, option.label)) unless shell.input_tty?
              return option.value
            end
            raise Error, "no answer for #{question.inspect} (choose one of: #{labels})" unless shell.input_tty?

            shell.err_puts("Please pick one of the choices or its number (1-#{options.size}).")
          end
        end
      end
    end

    extension :choose do
      helpers do
        def choose(question, choices, default: nil)
          options = Ext::Choose.options(choices)
          index = Ext::Choose.default_index(options, default)
          return Ext::Choose.ask_line(shell, question, options, index) unless shell.interactive?

          Prompt.run(shell, Ext::Choose::Model.new(shell, question, options, index)).value
        end
      end
    end
  end
end
