# frozen_string_literal: true

module R2UI
  # Column formats: how a value is shown, aligned, aggregated and parsed back from a search.
  module Format
    NUMERIC = %i[bytes bytes_per_sec percent number integer ratio].freeze
    SUMMED = %i[bytes bytes_per_sec percent number integer].freeze
    UNITS = { "" => 1, "K" => 1024, "M" => 1024**2, "G" => 1024**3, "T" => 1024**4 }.freeze

    module_function

    def numeric?(format) = NUMERIC.include?(format)

    # What a grouped line shows for this column: :sum, :count or :distinct.
    def default_aggregate(format)
      return :sum if SUMMED.include?(format)
      return :count if format == :id

      :distinct
    end

    def default_align(format) = numeric?(format) || format == :id ? :right : :left

    # Paths keep their tail when they don't fit.
    def truncate_from(format) = format == :short_path ? :left : :right

    def default_width(format)
      case format
      when :bytes, :bytes_per_sec then 8
      when :percent then 7
      when :ratio then 6
      when :id, :integer, :number then 8
      end
    end

    def call(format, value)
      return "" if value.nil?

      case format
      when :bytes then bytes(value)
      when :bytes_per_sec then "#{bytes(value)}/s"
      when :percent then format("%.1f%%", value)
      when :ratio then format("%.1fx", value)
      when :number then value.is_a?(Float) ? format("%.1f", value) : value.to_s
      when :short_path then short_path(value)
      else value.to_s
      end
    end

    def bytes(value)
      value = value.to_f
      unit = UNITS.keys.reverse.find { |u| value >= UNITS[u] } || ""
      scaled = value / UNITS[unit]
      unit.empty? ? "#{value.round}B" : format(scaled < 10 ? "%.1f%s" : "%.0f%s", scaled, unit)
    end

    def short_path(value)
      home = Dir.home
      value.to_s.start_with?(home) ? "~#{value.to_s.delete_prefix(home)}" : value.to_s
    end

    # Parse a search operand ("500M", "1.5G", "5") into the column's units.
    def parse(format, text)
      case format
      when :bytes, :bytes_per_sec
        m = text.strip.upcase.match(/\A([\d.]+)\s*([KMGT]?)I?B?\z/) or return nil
        m[1].to_f * UNITS[m[2]]
      when *NUMERIC, :id
        Float(text.delete("%x"), exception: false)
      else
        text
      end
    end
  end
end
