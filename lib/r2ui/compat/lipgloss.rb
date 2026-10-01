# frozen_string_literal: true

# Pure-Ruby Lipgloss: a drop-in for the lipgloss gem 0.2.2 (marcoroth/lipgloss-ruby, MIT), which wraps
# Go lipgloss v1.1.0 through a C extension. This port follows the Go sources (lipgloss v1.1.0,
# charmbracelet/x/ansi v0.8.0, muesli/termenv v0.16.0, lucasb-eyer/go-colorful v1.2.0, rivo/uniseg v0.4.7)
# so output is byte-identical to the real gem for the same calls and color profile.
#
# Public API lives under `Lipgloss`, exactly as the gem exposes it. Internals (text width and wrapping,
# terminal color handling, color math) live under `R2UI::Compat::Gloss` so they never leak into the
# gem's namespace.

require_relative "lipgloss/version"
require_relative "lipgloss/text"
require_relative "lipgloss/colorful"
require_relative "lipgloss/termenv"
require_relative "lipgloss/position"
require_relative "lipgloss/border"
require_relative "lipgloss/color"
require_relative "lipgloss/color_blend"
require_relative "lipgloss/style"
require_relative "lipgloss/layout"
require_relative "lipgloss/table"
require_relative "lipgloss/list"
require_relative "lipgloss/tree"

module Lipgloss
  TOP = Position::TOP
  BOTTOM = Position::BOTTOM
  LEFT = Position::LEFT
  RIGHT = Position::RIGHT
  CENTER = Position::CENTER

  NORMAL_BORDER = Border::NORMAL
  ROUNDED_BORDER = Border::ROUNDED
  THICK_BORDER = Border::THICK
  DOUBLE_BORDER = Border::DOUBLE
  HIDDEN_BORDER = Border::HIDDEN
  BLOCK_BORDER = Border::BLOCK
  ASCII_BORDER = Border::ASCII

  NO_TAB_CONVERSION = -1

  class << self
    def join_horizontal(position, *strings)
      _join_horizontal(Position.resolve(position), strings)
    end

    def join_vertical(position, *strings)
      _join_vertical(Position.resolve(position), strings)
    end

    def place(width, height, horizontal, vertical, string, **opts)
      _place(width, height, Position.resolve(horizontal), Position.resolve(vertical), string, **opts)
    end

    def place_horizontal(width, position, string)
      _place_horizontal(width, Position.resolve(position), string)
    end

    def place_vertical(height, position, string)
      _place_vertical(height, Position.resolve(position), string)
    end
  end
end
