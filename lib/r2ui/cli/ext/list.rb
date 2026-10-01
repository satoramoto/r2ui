# frozen_string_literal: true

# c16-list: bullet and numbered lists.
#
#   list(%w[rails pg puma])
#   list(["Build", %w[compile link], "Ship"], numbered: true)
#
# prints
#
#   • rails                       1. Build
#   • pg                             1. compile
#   • puma                           2. link
#                                 2. Ship
#
# A nested Array is a list one level in, under the text of the item before it; numbered lists
# number each level from 1 and right-align the numbers (" 9." over "10."). An item too long for
# the shell's width wraps on spaces (a word longer than the line is broken), and every wrapped
# line, like every line after a "\n" in an item, starts under the item's text, not its marker.
# Widths are display widths, so wide characters (漢字, emoji) wrap correctly.
#
# On a terminal the markers are in the accent colour. Off a terminal (pipe, CI, NO_COLOR) the
# same lines and layout, without escape codes. Lines go to stdout through the Shell, so inside a
# live region (tasks, spinners) they print above it. Returns nil.
module R2UI
  module CLI
    module Ext
      module BulletList
        # The narrowest text column a wrapped item gets, however deep or narrow the shell.
        MIN_TEXT_WIDTH = 4

        module_function

        # The lines for `items`, each a String; `indent` is the column the level starts at.
        def lines(shell, items, numbered:, indent: 0)
          items = entries(items)
          count = items.count { |item| !item.is_a?(Array) }
          number_width = count.to_s.size
          out = []
          bullet = shell.theme.symbol(:bullet)
          text_column = indent + (numbered ? number_width + 1 : Lipgloss.width(bullet)) + 1
          text_width = [shell.width - text_column, MIN_TEXT_WIDTH].max
          number = 0
          items.each do |item|
            if item.is_a?(Array)
              out.concat(lines(shell, item, numbered:, indent: text_column))
              next
            end

            number += 1
            marker = numbered ? "#{number.to_s.rjust(number_width)}." : bullet
            wrap(item.to_s, text_width).each_with_index do |line, i|
              lead = i.zero? ? "#{" " * indent}#{shell.paint(marker, :accent)} " : " " * text_column
              out << (line.empty? ? lead.rstrip : "#{lead}#{line}")
            end
          end
          out
        end

        def entries(items)
          return items if items.is_a?(Array)
          raise ArgumentError, "list needs an Array of items, got #{items.class}" if items.is_a?(Hash) || !items.is_a?(Enumerable)

          items.to_a
        end

        # Word-wraps text to `width` display cells; keeps the text's own line breaks.
        def wrap(text, width)
          text.split("\n", -1).flat_map { |paragraph| wrap_line(paragraph, width) }.then { |l| l.empty? ? [""] : l }
        end

        def wrap_line(text, width)
          lines = []
          current = +""
          text.split(/ +/).each do |word|
            next if word.empty?

            if current.empty?
              current = word
            elsif Lipgloss.width(current) + 1 + Lipgloss.width(word) <= width
              current << " " << word
            else
              lines << current
              current = word
            end
            while Lipgloss.width(current) > width
              head, current = split_at(current, width)
              lines << head
            end
          end
          lines << current
          lines
        end

        # Splits a word into the longest head that fits in `width` cells and the rest.
        def split_at(word, width)
          head = +""
          clusters = word.grapheme_clusters
          while (cluster = clusters.first) && Lipgloss.width(head + cluster) <= width
            head << clusters.shift
          end
          head << clusters.shift if head.empty? # a cluster wider than the line still has to go
          [head, clusters.join]
        end
      end
    end

    extension :list do
      helpers do
        def list(items, numbered: false)
          lines = Ext::BulletList.lines(shell, items, numbered:)
          shell.puts(lines.join("\n")) unless lines.empty?
          nil
        end
      end
    end
  end
end
