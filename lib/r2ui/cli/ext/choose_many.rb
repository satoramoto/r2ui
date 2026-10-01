# frozen_string_literal: true

# c20-choose-many: pick several from a list.
#
#   choose_many("Features?", %w[api web worker])                       # => ["api", "worker"]
#   choose_many("Features?", %w[api web worker], selected: %w[web], min: 1, max: 2)
#   choose_many("Install?", { "API server" => :api, "Web app" => :web }) # => [:api]
#
# Choices are an Array (each item is its own label, shown with to_s) or a Hash of label => value.
# `selected:` lists the values checked at the start (labels work too). The chosen values come back
# in list order, whatever order they were picked in.
#
# On a terminal (Shell#interactive?) it shows a checkbox list inline, like gum choose --no-limit:
#
#   ? Features?
#   › ◯ api
#     ◉ web
#     ◯ worker
#   space toggle · a all · enter submit
#
# ↑/↓ (k/j) move (wrapping), space toggles, a checks all (or clears all when all are checked), enter
# submits once the count is within `min:`..`max:` (otherwise it says "Pick at least 1" and waits).
# Past 10 items the list scrolls, with "↑ 3 more" / "↓ 4 more" hints. It leaves
# "✔ Features? · api, web" ("· none" for an empty answer) in the scrollback. ctrl+c or esc raises
# Interrupt (a command exits 130) after the terminal is restored.
#
# Off a terminal it reads one comma-separated line of labels (any case) or 1-based numbers:
# "web, 1". An empty line or end of input means `selected:`. When a person can still type (stdin
# is a terminal, stdout piped) it lists the numbered choices and asks
# "Features? (comma-separated) [web] " on stderr, asking again after an answer it can't use; from
# a pipe (`echo api,web | tool`, CI) it doesn't ask, records "✔ Features? · api, web" on stderr,
# and an unknown choice or a count outside min..max is an error naming the question.
module R2UI
  module CLI
    module Ext
      module ChooseMany
        PAGE = 10
        HINT = "space toggle · a all · enter submit"

        # Labels and values, in list order.
        Choices = Struct.new(:labels, :values) do
          def size = labels.size

          # Indexes for `selected:` values (or labels); raises on one that isn't a choice.
          def indexes_of(items)
            Array(items).map do |item|
              values.index(item) || labels.index(item.to_s) or
                raise ArgumentError, "selected: #{item.inspect} is not one of the choices"
            end
          end

          # The index for a typed label or 1-based number; nil when it matches nothing.
          def lookup(token)
            if token.match?(/\A\d+\z/)
              n = token.to_i
              return n - 1 if n.between?(1, size)

              return nil
            end
            labels.index(token) || labels.index { |label| label.casecmp?(token) }
          end
        end

        # The inline prompt: a Bubbletea model on R2UI::CLI::Prompt.
        class Model < Prompt::Model
          attr_reader :question

          def initialize(shell, question, choices, checked, min, max)
            super(shell)
            @question = question
            @choices = choices
            @checked = checked
            @min = min
            @max = max
            @cursor = 0
            @offset = 0
            @problem = nil
          end

          def view
            return "#{shell.symbol(:error)} #{question}" if interrupted?
            return ChooseMany.answered(shell, question, @choices, value_indexes) if done?

            lines = ["#{shell.paint("?", :accent)} #{question}"]
            lines << shell.paint("  ↑ #{@offset} more", :muted) if @offset.positive?
            visible.each { |i| lines << row(i) }
            below = @choices.size - (@offset + visible.size)
            lines << shell.paint("  ↓ #{below} more", :muted) if below.positive?
            lines << (@problem ? shell.paint(@problem, :warn) : shell.paint(HINT, :muted))
            lines.join("\n")
          end

          private

          def key(name, _message)
            case name
            when "up", "k" then move(-1)
            when "down", "j" then move(1)
            when "space", " " then toggle(@cursor)
            when "a" then toggle_all
            when "enter" then return finish
            else return nil
            end
            [self, nil]
          end

          def move(step)
            @cursor = (@cursor + step) % @choices.size
            @offset = @cursor if @cursor < @offset
            @offset = @cursor - PAGE + 1 if @cursor >= @offset + PAGE
          end

          def toggle(index)
            @problem = nil
            @checked.include?(index) ? @checked.delete(index) : @checked << index
          end

          def toggle_all
            @problem = nil
            @checked = @checked.size == @choices.size ? [] : (0...@choices.size).to_a
          end

          def finish
            @problem = ChooseMany.count_problem(@checked.size, @min, @max)
            return [self, nil] if @problem

            @indexes = @checked.sort
            submit(@indexes.map { |i| @choices.values[i] })
          end

          def value_indexes = @indexes || []

          def visible = (@offset...[@offset + PAGE, @choices.size].min).to_a

          def row(index)
            pointer = index == @cursor ? shell.paint(shell.theme.symbol(:pointer), :accent) : " "
            box = @checked.include?(index) ? shell.paint("◉", :success) : shell.paint("◯", :muted)
            label = @choices.labels[index]
            label = shell.paint(label, :highlight) if index == @cursor
            "#{pointer} #{box} #{label}"
          end
        end

        module_function

        def choices(list)
          raise ArgumentError, "choose_many needs at least one choice" if list.nil? || list.empty?

          if list.is_a?(Hash)
            Choices.new(list.keys.map(&:to_s), list.values)
          else
            Choices.new(list.map(&:to_s), list.to_a)
          end
        end

        def check_bounds(min, max)
          raise ArgumentError, "min: must be 0 or more" if min.negative?
          raise ArgumentError, "max: (#{max}) is less than min: (#{min})" if max && max < min
        end

        def build_model(shell, question, list, selected, min, max)
          check_bounds(min, max)
          choices = choices(list)
          Model.new(shell, question, choices, choices.indexes_of(selected).uniq, min, max)
        end

        # "Pick at least 1" / "Pick at most 2" when `count` is out of bounds, else nil.
        def count_problem(count, min, max)
          return "Pick at least #{min}" if count < min

          "Pick at most #{max}" if max && count > max
        end

        def answered(shell, question, choices, indexes)
          answer = indexes.empty? ? shell.paint("none", :muted) : shell.paint(indexes.map { |i| choices.labels[i] }.join(", "), :accent)
          "#{shell.symbol(:success)} #{question} #{shell.paint("·", :muted)} #{answer}"
        end

        # Sorted indexes for a typed line, `default` for an empty one; raises ArgumentError naming
        # the first token it can't read.
        def parse(line, choices, default)
          tokens = line.to_s.split(",").map(&:strip).reject(&:empty?)
          return default if tokens.empty?

          tokens.map { |token| choices.lookup(token) || raise(ArgumentError, token) }.uniq.sort
        end

        def ask_line(shell, question, list, selected, min, max)
          check_bounds(min, max)
          choices = choices(list)
          default = choices.indexes_of(selected).uniq.sort
          person = shell.input_tty?
          prompt = "#{question} (comma-separated) "
          prompt += "[#{default.map { |i| choices.labels[i] }.join(", ")}] " unless default.empty?
          list_choices(shell, choices) if person
          loop do
            line = Prompt.read_line(shell, prompt)
            problem =
              begin
                indexes = parse(line, choices, default)
                count_problem(indexes.size, min, max)
              rescue ArgumentError => e
                bad = e.message
                person ? "Unknown choice #{bad.inspect}" : "unknown choice #{bad.inspect} for #{question.inspect} (choices: #{choices.labels.join(", ")})"
              end
            unless problem
              shell.err_puts(plain_answer(shell, question, choices, indexes)) unless person
              return indexes.map { |i| choices.values[i] }
            end
            raise Error, (bad ? problem : "#{problem.sub("Pick", "pick")} for #{question.inspect}") unless person
            raise Error, "no answer for #{question.inspect}: #{problem.downcase}" if line.nil?

            shell.err_puts("#{problem}.")
          end
        end

        def list_choices(shell, choices)
          digits = choices.size.to_s.size
          choices.labels.each_with_index { |label, i| shell.err_puts("  #{(i + 1).to_s.rjust(digits)}. #{label}") }
        end

        def plain_answer(shell, question, choices, indexes)
          answer = indexes.empty? ? "none" : indexes.map { |i| choices.labels[i] }.join(", ")
          "#{shell.symbol(:success)} #{question} · #{answer}"
        end
      end
    end

    extension :choose_many do
      helpers do
        def choose_many(question, choices, selected: [], min: 0, max: nil)
          unless shell.interactive?
            return Ext::ChooseMany.ask_line(shell, question, choices, selected, min, max)
          end

          Prompt.run(shell, Ext::ChooseMany.build_model(shell, question, choices, selected, min, max)).value
        end
      end
    end
  end
end
