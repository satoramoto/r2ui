# frozen_string_literal: true

require "bigdecimal"

module ActiveR2UI
  # A decimal or float column's value. r2ui's :number format prints Floats with one decimal and
  # BigDecimals in scientific notation; this keeps the column's scale ("99.99", "12.50") while
  # staying a Numeric, so sorting, grouped sums and `total>50` searches still work.
  class Decimal < Numeric
    attr_reader :value, :scale

    def initialize(value, scale = nil)
      super()
      @value = value
      @scale = scale
    end

    def self.wrap(value, scale = nil) = value.nil? ? nil : new(value, scale)

    def to_f = value.to_f

    def to_s
      return format("%.#{scale}f", value) if scale&.positive?
      return value.to_i.to_s if scale&.zero?

      value.is_a?(BigDecimal) ? value.to_s("F").delete_suffix(".0") : value.to_s
    end
    alias inspect to_s

    def <=>(other) = other.is_a?(Numeric) ? to_f <=> other.to_f : nil

    def ==(other) = other.is_a?(Numeric) && to_f == other.to_f
    alias eql? ==

    def hash = to_f.hash

    def +(other) = Decimal.new(value + (other.is_a?(Decimal) ? other.value : other), scale)

    def -(other) = Decimal.new(value - (other.is_a?(Decimal) ? other.value : other), scale)

    # `0 + decimal` (Array#sum starts from 0) and other Integer/Float arithmetic.
    def coerce(other) = [Decimal.new(other, scale), self]

    def zero? = value.zero?
  end
end
