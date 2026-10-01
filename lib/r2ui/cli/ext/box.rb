# frozen_string_literal: true

# c07-box: a boxed notice, like npm's "Update available" or a "Next steps" box after scaffolding.
#
#   box "Created app\n\n  cd app\n  bin/dev", title: "Next steps"
#   box "Update available 1.3.0 → 1.4.0\nRun gem update deployer", title: "deployer", style: :warn
#
# prints a rounded lipgloss border with the title in its top border:
#
#   ╭─ Next steps ─────╮
#   │                  │
#   │  Created app     │
#   │                  │
#   │    cd app        │
#   │    bin/dev       │
#   │                  │
#   ╰──────────────────╯
#
# On a terminal the border and the title are drawn in the style's colour (a Theme name: :info,
# the default, :success, :warn, :error, :accent, :muted, ...; the title also bold); the text keeps
# its own styling. Off a terminal (a pipe, CI, NO_COLOR) it prints the same box, character for
# character, without escape codes, so logs and `| cat` read the same.
#
# The box fits its text, never wider than the shell: longer lines wrap inside it (words first,
# then hard breaks). `width:` fixes the outer width (border included), still capped at the shell.
# `padding:` is the space inside the border: an Integer n is n blank lines above and below and 2n
# columns either side (cells are about twice as tall as wide); `[vertical, horizontal]` sets both.
# Multi-line text, tabs and wide characters (CJK, emoji) keep the right edge aligned. A title too
# wide for the top border becomes the box's first line instead. Returns nil.
module R2UI
  module CLI
    module Ext
      module Box
        BORDER = Lipgloss::Style.new.border(:rounded)
        TOP_LEFT = "╭"
        TOP_RIGHT = "╮"
        TOP = "─"

        module_function

        def render(shell, text, title:, style:, padding:, width:)
          shell.theme.options(style) # unknown names raise, coloured or not
          vertical, horizontal = spacing(padding)
          text = text.to_s
          title = title&.to_s&.tr("\n", " ")
          title = nil if title&.empty?
          max = [width ? width.to_i : shell.width, shell.width].min
          horizontal = [horizontal, [(max - 3) / 2, 0].max].min
          inner = width ? max - 2 : natural(text, title, horizontal, max)
          inner = [inner, 1].max

          in_border = title && fits?(title, inner)
          body = in_border || title.nil? ? text : "#{shell.paint(title, :heading, style)}\n#{text}"
          plain = BORDER.padding(vertical, horizontal).width(inner).render(body)
          lines = plain.split("\n")
          lines[0] = in_border ? top(shell, title, inner, style) : shell.paint(lines[0], style)
          lines[-1] = shell.paint(lines[-1], style)
          lines[1..-2].each_with_index do |line, i|
            lines[i + 1] = side(shell, line, style)
          end
          lines.join("\n")
        end

        def spacing(padding)
          case padding
          when Integer then [padding, padding * 2]
          when Array
            raise ArgumentError, "padding: needs [vertical, horizontal]" unless padding.size == 2

            padding.map(&:to_i)
          else raise ArgumentError, "padding: must be an Integer or [vertical, horizontal]"
          end.map { |n| [n, 0].max }
        end

        # The inner width (padding included) that fits the text and the title, capped by `max`.
        def natural(text, title, horizontal, max)
          widest = text.split("\n").map { |line| Lipgloss.width(line.gsub("\t", "    ")) }.max || 0
          inner = widest + (2 * horizontal)
          inner = [inner, title_width(title)].max if title
          [inner, max - 2].min
        end

        def title_width(title) = Lipgloss.width(title) + 4

        def fits?(title, inner) = title_width(title) <= inner

        # "╭─ Title ───╮": the title in the top border, the rest of it in the style's colour.
        def top(shell, title, inner, style)
          rest = inner - Lipgloss.width(title) - 3
          "#{shell.paint("#{TOP_LEFT}#{TOP} ", style)}#{shell.paint(title, :heading, style)}" \
            "#{shell.paint(" #{TOP * rest}#{TOP_RIGHT}", style)}"
        end

        # A middle line: its first and last characters are the border; the text between is left as is.
        def side(shell, line, style)
          left = line[0]
          right = line[-1]
          "#{shell.paint(left, style)}#{line[1..-2]}#{shell.paint(right, style)}"
        end
      end
    end

    extension :box do
      helpers do
        def box(text, title: nil, style: :info, padding: 1, width: nil)
          shell.puts(Ext::Box.render(shell, text, title:, style:, padding:, width:))
          nil
        end
      end
    end
  end
end
