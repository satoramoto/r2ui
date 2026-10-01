# frozen_string_literal: true

# Same as lipgloss-ruby 0.2.2 lib/lipgloss/position.rb (MIT).
module Lipgloss
  # Positions are floats from 0.0 (top/left) to 1.0 (bottom/right); 0.5 is center.
  module Position
    TOP = 0.0
    BOTTOM = 1.0
    LEFT = 0.0
    RIGHT = 1.0
    CENTER = 0.5

    SYMBOLS = {
      top: TOP,
      bottom: BOTTOM,
      left: LEFT,
      right: RIGHT,
      center: CENTER
    }.freeze

    def self.resolve(value)
      case value
      when Symbol then SYMBOLS.fetch(value) { raise ArgumentError, "Unknown position: #{value.inspect}" }
      when String then SYMBOLS.fetch(value.to_sym) { raise ArgumentError, "Unknown position: #{value.inspect}" }
      when Numeric then value.to_f
      else raise ArgumentError, "Position must be a Symbol or Numeric, got #{value.class}"
      end
    end
  end
end
