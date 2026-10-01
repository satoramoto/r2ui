# frozen_string_literal: true

# Border definitions: lipgloss v1.1.0 borders.go (the Border struct and its predefined borders), plus
# the border-type conversion the lipgloss gem 0.2.2 C extension does (style_border.c
# symbol_to_border_type and go/style_border.go).
module R2UI
  module Compat
    module Gloss
      # lipgloss.Border, fields snake_cased. Unset (nil) fields count as "" (Go's zero value).
      BorderDef = Struct.new(
        :top, :bottom, :left, :right,
        :top_left, :top_right, :bottom_left, :bottom_right,
        :middle_left, :middle_right, :middle,
        :middle_top, :middle_bottom
      ) do
        # A copy with every nil field turned into "" (Go's zero-value string).
        def normalized
          self.class.new(*to_a.map { |v| v.nil? ? "" : v.to_s })
        end

        # Border.GetTopSize etc.
        def top_size = Borders.edge_width(top_left, top, top_right)
        def right_size = Borders.edge_width(top_right, right, bottom_right)
        def bottom_size = Borders.edge_width(bottom_left, bottom, bottom_right)
        def left_size = Borders.edge_width(top_left, left, bottom_left)
      end

      module Borders
        def self.define(**fields)
          BorderDef.new(**BorderDef.members.to_h { |m| [m, ""] }.merge(fields)).freeze
        end
        private_class_method :define

        NO_BORDER = define

        NORMAL = define(
          top: "─", bottom: "─", left: "│", right: "│",
          top_left: "┌", top_right: "┐", bottom_left: "└", bottom_right: "┘",
          middle_left: "├", middle_right: "┤", middle: "┼", middle_top: "┬", middle_bottom: "┴"
        )

        ROUNDED = define(
          top: "─", bottom: "─", left: "│", right: "│",
          top_left: "╭", top_right: "╮", bottom_left: "╰", bottom_right: "╯",
          middle_left: "├", middle_right: "┤", middle: "┼", middle_top: "┬", middle_bottom: "┴"
        )

        BLOCK = define(
          top: "█", bottom: "█", left: "█", right: "█",
          top_left: "█", top_right: "█", bottom_left: "█", bottom_right: "█",
          middle_left: "█", middle_right: "█", middle: "█", middle_top: "█", middle_bottom: "█"
        )

        OUTER_HALF_BLOCK = define(
          top: "▀", bottom: "▄", left: "▌", right: "▐",
          top_left: "▛", top_right: "▜", bottom_left: "▙", bottom_right: "▟"
        )

        INNER_HALF_BLOCK = define(
          top: "▄", bottom: "▀", left: "▐", right: "▌",
          top_left: "▗", top_right: "▖", bottom_left: "▝", bottom_right: "▘"
        )

        THICK = define(
          top: "━", bottom: "━", left: "┃", right: "┃",
          top_left: "┏", top_right: "┓", bottom_left: "┗", bottom_right: "┛",
          middle_left: "┣", middle_right: "┫", middle: "╋", middle_top: "┳", middle_bottom: "┻"
        )

        DOUBLE = define(
          top: "═", bottom: "═", left: "║", right: "║",
          top_left: "╔", top_right: "╗", bottom_left: "╚", bottom_right: "╝",
          middle_left: "╠", middle_right: "╣", middle: "╬", middle_top: "╦", middle_bottom: "╩"
        )

        HIDDEN = define(
          top: " ", bottom: " ", left: " ", right: " ",
          top_left: " ", top_right: " ", bottom_left: " ", bottom_right: " ",
          middle_left: " ", middle_right: " ", middle: " ", middle_top: " ", middle_bottom: " "
        )

        MARKDOWN = define(
          top: "-", bottom: "-", left: "|", right: "|",
          top_left: "|", top_right: "|", bottom_left: "|", bottom_right: "|",
          middle_left: "|", middle_right: "|", middle: "|", middle_top: "|", middle_bottom: "|"
        )

        ASCII = define(
          top: "-", bottom: "-", left: "|", right: "|",
          top_left: "+", top_right: "+", bottom_left: "+", bottom_right: "+",
          middle_left: "+", middle_right: "+", middle: "+", middle_top: "+", middle_bottom: "+"
        )

        BY_NAME = {
          normal: NORMAL, rounded: ROUNDED, block: BLOCK, outer_half_block: OUTER_HALF_BLOCK,
          inner_half_block: INNER_HALF_BLOCK, thick: THICK, double: DOUBLE, hidden: HIDDEN,
          markdown: MARKDOWN, ascii: ASCII
        }.freeze

        # The border types the gem's C extension recognizes (no :markdown there).
        GEM_TYPES = %i[normal rounded thick double hidden block outer_half_block inner_half_block ascii].freeze

        class << self
          # NormalBorder(), RoundedBorder(), ... by name.
          def fetch(name)
            BY_NAME.fetch(name.to_sym) { raise KeyError, "unknown border #{name.inspect}" }
          end

          # What the C extension does with a border-type argument: one of its nine exact Symbols, or
          # the normal border for anything else (strings, nil, :markdown, unknown symbols).
          def resolve(value)
            value.is_a?(Symbol) && GEM_TYPES.include?(value) ? BY_NAME.fetch(value) : NORMAL
          end

          # getBorderEdgeWidth
          def edge_width(*parts)
            parts.map { |piece| max_rune_width(piece.to_s) }.max || 0
          end

          # borders.go maxRuneWidth: the widest grapheme cluster.
          def max_rune_width(str)
            width = 0
            state = -1
            until str.empty?
              _cluster, str, w, state = Text.first_grapheme_cluster_in_string(str, state)
              width = w if w > width
            end
            width
          end
        end
      end
    end
  end
end
