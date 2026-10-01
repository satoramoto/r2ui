# frozen_string_literal: true

# c21-filter: type to filter a list, like gum filter or fzf.
#
#   branch = filter("Branch?", `git branch --format=%(refname:short)`.lines(chomp: true))
#   region = filter("Region?", { "Europe (eu-west-1)" => :eu, "US East (us-east-1)" => :us })
#   filter("Package?", packages, placeholder: "name or scope", limit: 8)
#
# On a terminal (Shell#interactive?) it asks inline: a bubbles TextInput on the question line,
# and under it the choices narrowed by a fuzzy match as you type (the characters may be spread
# out: "fbil" finds "feature/billing"; contiguous runs and word starts rank first, ties keep the
# list's order), the matched characters highlighted:
#
#   ? Branch? feat▌  2/6
#   › feature/billing
#     feature/login
#
# ↑/↓ (ctrl+p/ctrl+n, ctrl+k/ctrl+j) move, enter picks, the usual line-editing keys edit the
# query. At most `limit:` (10) rows show at once, with "↑ 3 more" / "↓ 5 more" hints. It leaves
# "✔ Branch? · feature/billing" in the scrollback; ctrl+c or esc raises Interrupt (a command exits
# 130) after the terminal is restored.
#
# Off a terminal it reads one line and returns the best match for it ("bill" → feature/billing).
# It asks "Branch? " on stderr when a person can type (stdin is a terminal, stdout piped); from a
# pipe (`echo bill | tool`, CI) it doesn't ask and records "✔ Branch? · feature/billing" on
# stderr. A line nothing matches, an empty line or end of input raise a CLI::Error naming the
# question (a command exits 1).
#
# Choices are an Array (the item is returned) or a Hash of label ⇒ value (the value is returned).
module R2UI
  module CLI
    module Ext
      module Filter
        # Fuzzy scoring, in the spirit of fzf: every query character must appear in order; a match
        # earns MATCH per character, more at a word start or right after the previous match, less
        # for each character skipped in between.
        MATCH = 16
        BOUNDARY = 8
        CAMEL = 7
        CONSECUTIVE = 6
        GAP_START = 3
        GAP = 1
        EXACT = 1000

        # A choice as the list shows it: its label, what picking it returns, its place in the list.
        Choice = Data.define(:label, :value, :index)

        # A choice that matched: its score and the label positions that matched.
        Match = Data.define(:choice, :score, :positions)

        # The inline prompt: a Bubbletea model on R2UI::CLI::Prompt hosting a bubbles TextInput.
        class Model < Prompt::Model
          attr_reader :question, :matches, :cursor

          def initialize(shell, question, choices, limit: 10, placeholder: "Type to filter")
            super(shell)
            @question = question
            @choices = Filter.choices(choices)
            @limit = [[limit, shell.height - 3].min, 1].max
            input = Bubbles::TextInput.new
            input.prompt = ""
            input.placeholder = placeholder
            input.placeholder_style = shell.theme.style(:muted) if shell.color?
            @focus_command = input.focus
            self.component = input
            @query = nil
            refilter
          end

          def init = [self, @focus_command]

          def update(message)
            result = super
            refilter unless done? || component.value == @query
            result
          end

          def view
            return "#{shell.symbol(:error)} #{question}" if interrupted?
            return Filter.answered(shell, question, @picked.label) if done?

            [header, *rows].join("\n")
          end

          private

          def key(name, _message)
            case name
            when "enter"
              return [self, nil] if matches.empty?

              @picked = matches[cursor].choice
              submit(@picked.value)
            when "up", "ctrl+p", "ctrl+k" then move(-1)
            when "down", "ctrl+n", "ctrl+j" then move(1)
            end
          end

          def move(step)
            @cursor = (cursor + step).clamp(0, [matches.size - 1, 0].max)
            @offset = cursor if cursor < @offset
            @offset = cursor - @limit + 1 if cursor >= @offset + @limit
            [self, nil]
          end

          def refilter
            @query = component.value
            @matches = Filter.rank(@query, @choices)
            @cursor = 0
            @offset = 0
          end

          def header
            count = shell.paint("#{matches.size}/#{@choices.size}", :muted)
            "#{shell.paint("?", :accent)} #{question} #{component.view}  #{count}"
          end

          def rows
            return ["  #{shell.paint("No matches", :muted)}"] if matches.empty?

            above = @offset
            below = matches.size - @offset - @limit
            lines = []
            lines << "  #{shell.paint("↑ #{above} more", :muted)}" if above.positive?
            matches[@offset, @limit].each_with_index { |match, i| lines << row(match, @offset + i == cursor) }
            lines << "  #{shell.paint("↓ #{below} more", :muted)}" if below.positive?
            lines
          end

          # The pointer marks the row without colour too (NO_COLOR on a terminal).
          def row(match, selected)
            room = [shell.width - 2, 1].max
            label = match.choice.label
            label = "#{label[0, room - 1]}…" if label.size > room
            base = selected ? [:accent] : []
            text = Filter.highlight(shell, label, match.positions, base)
            selected ? "#{shell.paint(shell.theme.symbol(:pointer), :accent)} #{text}" : "  #{text}"
          end
        end

        module_function

        def choices(list)
          return list if list.is_a?(Array) && list.all?(Choice)

          pairs = list.is_a?(Hash) ? list.to_a : Array(list).map { |item| [item, item] }
          pairs.each_with_index.map { |(label, value), index| Choice.new(label: label.to_s, value:, index:) }
        end

        # The choices that match `query`, best first; an empty query keeps them all, in order.
        def rank(query, choices)
          matches = choices.filter_map do |choice|
            score, positions = score(query, choice.label)
            Match.new(choice:, score:, positions:) if score
          end
          matches.sort_by { |m| [-m.score, m.choice.index] }
        end

        # [score, matched positions] for `query` in `label`, or nil when it doesn't match. The
        # best alignment by dynamic programming: score[i][j] is the best score with query
        # character i at label position j.
        def score(query, label)
          q = query.downcase.chars
          return [0, []] if q.empty?

          chars = label.chars
          lower = chars.map(&:downcase)
          return nil if q.size > chars.size

          scores = Array.new(q.size) { Array.new(chars.size) }
          from = Array.new(q.size) { Array.new(chars.size) }
          q.each_with_index do |qc, i|
            gapped = nil # best score[i - 1][k] for k <= j - 2, less the gap penalty up to j
            gapped_from = nil
            chars.each_index do |j|
              if i.positive? && j >= 2 && (prev = scores[i - 1][j - 2])
                gapped -= GAP if gapped
                if gapped.nil? || prev - GAP_START >= gapped
                  gapped = prev - GAP_START
                  gapped_from = j - 2
                end
              elsif gapped
                gapped -= GAP
              end
              next unless lower[j] == qc

              bonus = MATCH + bonus(chars, j)
              if i.zero?
                scores[i][j] = bonus
                next
              end

              best = nil
              if j >= 1 && (prev = scores[i - 1][j - 1])
                best = prev + bonus + CONSECUTIVE
                from[i][j] = j - 1
              end
              if gapped && (best.nil? || gapped + bonus > best)
                best = gapped + bonus
                from[i][j] = gapped_from
              end
              scores[i][j] = best
            end
          end

          last = scores.last
          j = last.each_index.select { |k| last[k] }.max_by { |k| [last[k], -k] }
          return nil unless j

          total = last[j]
          positions = [j]
          (q.size - 1).downto(1) { |i| positions.unshift(j = from[i][j]) }
          total += EXACT if query.downcase == label.downcase
          [total, positions]
        end

        def bonus(chars, j)
          return BOUNDARY if j.zero?

          before = chars[j - 1]
          return BOUNDARY unless before.match?(/[[:alnum:]]/)
          return CAMEL if before.match?(/[[:lower:]]/) && chars[j].match?(/[[:upper:]]/)

          0
        end

        # The label with matched characters in the highlight style (runs painted together).
        def highlight(shell, label, positions, base)
          matched = positions.to_h { |p| [p, true] }
          label.chars.each_with_index.chunk_while { |(_, a), (_, b)| matched[a] == matched[b] }.map do |run|
            text = run.map(&:first).join
            matched[run.first.last] ? shell.paint(text, :highlight) : shell.paint(text, *base)
          end.join
        end

        def answered(shell, question, label)
          "#{shell.symbol(:success)} #{question} #{shell.paint("·", :muted)} #{shell.paint(label, :accent)}"
        end

        def ask_line(shell, question, choices)
          line = Prompt.read_line(shell, "#{question} ")
          query = line.to_s.strip
          raise Error, "no answer for #{question.inspect} (end of input)" if line.nil?
          raise Error, "no answer for #{question.inspect}" if query.empty?

          best = rank(query, choices).first
          raise Error, "nothing matches #{query.inspect} for #{question.inspect}" unless best

          shell.err_puts("#{shell.symbol(:success)} #{question} · #{best.choice.label}") unless shell.input_tty?
          best.choice.value
        end
      end
    end

    extension :filter do
      helpers do
        def filter(question, choices, limit: 10, placeholder: "Type to filter")
          list = Ext::Filter.choices(choices)
          raise Error, "nothing to choose from for #{question.inspect}" if list.empty?
          return Ext::Filter.ask_line(shell, question, list) unless shell.interactive?

          CLI.require_bubbles!
          model = Ext::Filter::Model.new(shell, question, choices, limit:, placeholder:)
          Prompt.run(shell, model).value
        end
      end
    end
  end
end
