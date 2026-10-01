# frozen_string_literal: true

# c11-diff: a unified diff of two texts, the way `git diff` and `diff -u` print one.
#
#   changed = diff(deployed_config, local_config, labels: ["config.yml (deployed)", "config.yml (local)"])
#   say "Nothing to deploy", :muted unless changed
#
# prints
#
#   --- config.yml (deployed)
#   +++ config.yml (local)
#   @@ -2,4 +2,4 @@
#    env: production
#   -replicas: 2
#   +replicas: 4
#    region: eu
#    timeout: 30
#
# and returns true. Equal texts print nothing and return false, so `diff(a, b) or say("up to date")`
# reads naturally.
#
# `old` and `new` are Strings (split into lines) or Arrays of lines. `labels:` names the two sides
# in the `---`/`+++` header (default `a` and `b`); `context:` is how many unchanged lines surround
# each change (default 3, 0 for none); changes closer than twice that share a hunk. Hunk headers
# use diff's numbering (`@@ -3,0 +4 @@` is an insertion after line 3), and a last line without a
# newline is followed by "\ No newline at end of file", so the output is a patch `patch`/`git apply`
# accept. The edit is minimal: a pure-Ruby LCS (Myers' O(ND) algorithm, after trimming the common
# head and tail), fast on large files with few changes.
#
# On a terminal (Shell#color?) the header is bold, hunk headers muted, removed lines red and added
# lines green; tabs and trailing spaces are kept as they are. Off a terminal (a pipe, CI,
# `NO_COLOR`) the same text without escape codes. It goes to stdout through the Shell; inside a
# Live region (tasks, spinners) it prints above it.
module R2UI
  module CLI
    module Ext
      module UnifiedDiff
        # One line of the edit: :same, :del or :ins, the line (with its newline, if it has one),
        # and how many lines of each side come before it.
        Op = Struct.new(:kind, :line, :a, :b)

        SIGNS = { same: " ", del: "-", ins: "+" }.freeze
        STYLES = { same: [], del: [:error], ins: [:success] }.freeze
        NO_NEWLINE = "\\ No newline at end of file"

        module_function

        # The diff's lines (without newlines), painted for the shell; [] when the texts are equal.
        def render(shell, old, new, labels:, context:)
          ops = edits(lines(old), lines(new))
          groups = hunks(ops, context)
          return [] if groups.empty?

          out = ["--- #{labels[0]}", "+++ #{labels[1]}"].map { |l| shell.paint(l, :heading) }
          groups.each do |hunk|
            out << shell.paint(header(hunk), :muted)
            hunk.each do |op|
              text = op.line.chomp
              out << paint_line(shell, "#{SIGNS[op.kind]}#{text}", STYLES[op.kind])
              out << shell.paint(NO_NEWLINE, :muted) unless op.line.end_with?("\n")
            end
          end
          out
        end

        def lines(text)
          return text.map { |line| "#{line.to_s.chomp}\n" } if text.is_a?(Array)

          text.to_s.lines
        end

        # Paints around tabs: lipgloss would expand them, and the text must stay the same.
        def paint_line(shell, line, styles)
          return line if styles.empty?

          line.split("\t", -1).map { |part| shell.paint(part, *styles) }.join("\t")
        end

        # The edit from a to b, as Ops in order.
        def edits(a, b)
          head = 0
          head += 1 while head < a.size && head < b.size && a[head] == b[head]
          tail = 0
          tail += 1 while tail < a.size - head && tail < b.size - head && a[-1 - tail] == b[-1 - tail]
          kinds = Array.new(head, :same) +
                  myers(a[head...(a.size - tail)], b[head...(b.size - tail)]) +
                  Array.new(tail, :same)

          i = j = 0
          kinds.map do |kind|
            op = Op.new(kind, kind == :ins ? b[j] : a[i], i, j)
            i += 1 unless kind == :ins
            j += 1 unless kind == :del
            op
          end
        end

        # Myers' greedy shortest edit script: the kinds of each step, deletions before insertions.
        def myers(a, b)
          n = a.size
          m = b.size
          return Array.new(m, :ins) if n.zero?
          return Array.new(n, :del) if m.zero?

          v = { 1 => 0 }
          trace = []
          (0..(n + m)).each do |d|
            trace << v.dup
            (-d..d).step(2) do |k|
              x = down?(v, k, d) ? v[k + 1] : v[k - 1] + 1
              y = x - k
              while x < n && y < m && a[x] == b[y]
                x += 1
                y += 1
              end
              v[k] = x
              return backtrack(trace, n, m) if x >= n && y >= m
            end
          end
        end

        def down?(v, k, d) = k == -d || (k != d && v[k - 1] < v[k + 1])

        def backtrack(trace, n, m)
          x = n
          y = m
          kinds = []
          (trace.size - 1).downto(0) do |d|
            v = trace[d]
            k = x - y
            prev_k = down?(v, k, d) ? k + 1 : k - 1
            prev_x = v[prev_k]
            prev_y = prev_x - prev_k
            while x > prev_x && y > prev_y
              kinds << :same
              x -= 1
              y -= 1
            end
            kinds << (x == prev_x ? :ins : :del) if d.positive?
            x = prev_x
            y = prev_y
          end
          kinds.reverse
        end

        # The Ops of each hunk: changes with `context` lines around them, merged when they'd touch.
        def hunks(ops, context)
          ranges = []
          ops.each_with_index do |op, i|
            next if op.kind == :same

            if ranges.any? && i - ranges.last[1] - 1 <= 2 * context
              ranges.last[1] = i
            else
              ranges << [i, i]
            end
          end
          ranges.map do |first, last|
            ops[[first - context, 0].max..[last + context, ops.size - 1].min]
          end
        end

        def header(hunk)
          old_count = hunk.count { |op| op.kind != :ins }
          new_count = hunk.count { |op| op.kind != :del }
          "@@ -#{range(hunk.first.a, old_count)} +#{range(hunk.first.b, new_count)} @@"
        end

        # diff's numbering: 1-based; an empty range names the line before it.
        def range(start, count)
          case count
          when 0 then "#{start},0"
          when 1 then (start + 1).to_s
          else "#{start + 1},#{count}"
          end
        end
      end
    end

    extension :diff do
      helpers do
        def diff(old, new, labels: %w[a b], context: 3)
          unless context.is_a?(Integer) && !context.negative?
            raise ArgumentError, "context must be a non-negative Integer, not #{context.inspect}"
          end
          raise ArgumentError, "labels must be two names" unless labels.respond_to?(:size) && labels.size == 2

          lines = Ext::UnifiedDiff.render(shell, old, new, labels: labels.to_a, context:)
          lines.each { |line| shell.puts(line) }
          !lines.empty?
        end
      end
    end
  end
end
