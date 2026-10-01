# frozen_string_literal: true

# c09-pairs: an aligned key/value summary, like the block `npm publish` or `gh repo view` prints.
#
#   pairs({ "Version" => "1.4.0", "Env" => "production", "Region" => nil }, title: "Deploy")
#
# prints
#
#   Deploy
#     Version  1.4.0
#     Env      production
#     Region   —
#
# Keys are right-padded to the longest key (by display width, so wide characters line up) and
# followed by two spaces. With a `title:` the title is its own line and the pairs are indented
# under it by two spaces; without one they start at the left edge. A nil value shows "—"; other
# keys and values are shown with `to_s`. A multi-line value continues under the value column. An
# empty hash prints only the title (or nothing). Pairs may also be given as an Array of
# [key, value] (order and repeated keys kept). Returns nil.
#
# On a terminal (Shell#color?) the title is bold, keys and the "—" are muted, values are plain.
# Off a terminal, or with NO_COLOR, it prints the same text and alignment with no escape codes.
# Inside a Live region (a `tasks` step) the lines print above it, as `say` does.
module R2UI
  module CLI
    module Ext
      module Pairs
        GAP = "  "
        INDENT = "  "
        NONE = "—"

        module_function

        def lines(shell, entries, title)
          entries = entries.to_a.map { |key, value| [key.to_s, value] }
          out = []
          out << shell.paint(title.to_s, :heading) unless title.nil?
          indent = title.nil? ? "" : INDENT
          width = entries.map { |key, _| Lipgloss.width(key) }.max || 0
          entries.each do |key, value|
            pad = " " * (width - Lipgloss.width(key))
            first, *rest = value.nil? ? [shell.paint(NONE, :muted)] : value.to_s.split("\n", -1)
            label = "#{indent}#{shell.paint(key, :muted)}"
            out << (first.to_s.empty? ? label : "#{label}#{pad}#{GAP}#{first}")
            continuation = indent + (" " * (width + GAP.length))
            rest.each { |line| out << (line.empty? ? "" : "#{continuation}#{line}") }
          end
          out
        end
      end
    end

    extension :pairs do
      helpers do
        def pairs(entries, title: nil)
          Ext::Pairs.lines(shell, entries, title).each { |line| shell.puts(line) }
          nil
        end
      end
    end
  end
end
