# frozen_string_literal: true

module R2UI
  # Human formats for both products: the dashboard's column formats (how a value is shown, aligned,
  # aggregated and parsed back from a search) and the CLI's helpers (duration, bytes, plural).
  # No dependencies, so the CLI toolkit can load it without the dashboard DSL.
  module Format
    NUMERIC = %i[bytes bytes_per_sec si_bytes duration percent number integer ratio].freeze
    SUMMED = %i[bytes bytes_per_sec si_bytes duration percent number integer].freeze
    UNITS = { "" => 1, "K" => 1024, "M" => 1024**2, "G" => 1024**3, "T" => 1024**4 }.freeze
    SI_UNITS = %w[B kB MB GB TB PB EB].freeze
    SECONDS = { "ms" => 0.001, "s" => 1, "m" => 60, "h" => 3600, "d" => 86_400 }.freeze

    module_function

    def numeric?(format) = NUMERIC.include?(format)

    # What a grouped line shows for this column: :sum, :count, :min or :distinct.
    def default_aggregate(format)
      return :sum if SUMMED.include?(format)
      return :count if format == :id
      return :min if format == :age

      :distinct
    end

    def default_align(format) = numeric?(format) || %i[id age].include?(format) ? :right : :left

    # Paths keep their tail when they don't fit.
    def truncate_from(format) = format == :short_path ? :left : :right

    def default_width(format)
      case format
      when :bytes, :bytes_per_sec, :si_bytes, :duration, :age then 8
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
      when :si_bytes then si_bytes(value)
      when :duration then duration(value)
      when :age then age(value)
      when :percent then format("%.1f%%", value)
      when :ratio then format("%.1fx", value)
      when :number then value.is_a?(Float) ? format("%.1f", value) : value.to_s
      when :short_path then short_path(value)
      else value.to_s
      end
    end

    # Binary units with one-letter names: "999B", "1.0K", "1.5K", "10K", "400M", "2.0G".
    # Rounds before picking the unit, so 1000 and 1023 are "1.0K", never "1000B".
    def bytes(value)
      value = Float(value)
      return "-#{bytes(-value)}" if value.negative? && value.round.nonzero?

      value = value.abs
      units = UNITS.keys
      index = 0
      index += 1 while index < units.size - 1 && binary_scaled(value, index) >= 1000
      return "#{value.round}B" if index.zero?

      scaled = binary_scaled(value, index)
      format(scaled < 10 ? "%.1f%s" : "%.0f%s", scaled, units[index])
    end

    def binary_scaled(value, index)
      scaled = value / (1024**index)
      return scaled.round if index.zero?

      scaled.round(1) < 10 ? scaled.round(1) : scaled.round
    end

    # Decimal units like npm and the OS file managers: "999 B", "12 kB", "1.5 MB", "4.2 GB".
    # Rounds before picking the unit, so 999_999 is "1 MB", not "1000 kB".
    def si_bytes(count)
      count = Float(count)
      return "-#{si_bytes(-count)}" if count.negative?

      unit = 0
      unit += 1 while unit < SI_UNITS.size - 1 && si_scaled(count, unit) >= 1000
      value = si_scaled(count, unit)
      "#{value == value.to_i ? value.to_i : value} #{SI_UNITS[unit]}"
    end

    def si_scaled(count, unit)
      value = count / (1000**unit)
      value < 10 && unit.positive? ? value.round(1) : value.round
    end

    # "120ms" under a second, "3.5s" under a minute, then "1m 15s", "2h 30m", "1d 2h".
    # Rounds before picking the unit, so 59.97 is "1m 0s".
    def duration(seconds)
      seconds = Float(seconds)
      return "-#{duration(-seconds)}" if seconds.negative?

      ms = (seconds * 1000).round
      return "#{ms}ms" if ms < 1000

      tenths = (seconds * 10).round
      return "#{format("%.1f", tenths / 10.0)}s" if tenths < 600

      total = seconds.round
      return "#{total / 60}m #{total % 60}s" if total < 3600

      minutes = (total / 60.0).round
      return "#{minutes / 60}h #{minutes % 60}m" if minutes < 24 * 60

      hours = (total / 3600.0).round
      "#{hours / 24}d #{hours % 24}h"
    end

    # How long ago a Time (or epoch seconds) was, as a duration.
    def age(value, now: Time.now)
      then_seconds = value.is_a?(Time) ? value.to_f : Float(value)
      duration(now.to_f - then_seconds)
    end

    # "3 packages", "1 package", "2 dependencies", "1,234 files"; pass the plural for irregular words.
    def plural(count, word, plural = nil)
      form = count == 1 ? word : plural || pluralize(word)
      "#{delimit(count)} #{form}"
    end

    def pluralize(word)
      case word
      when /[^aeiou]y\z/i then "#{word[0..-2]}ies"
      when /(?:s|x|z|ch|sh)\z/i then "#{word}es"
      else "#{word}s"
      end
    end

    # Thousands separators: 1234567 → "1,234,567".
    def delimit(count)
      whole, fraction = count.to_s.split(".", 2)
      whole = whole.reverse.scan(/\d{1,3}/).join(",").reverse.then { |w| whole.start_with?("-") ? "-#{w}" : w }
      fraction ? "#{whole}.#{fraction}" : whole
    end

    def short_path(value)
      home = Dir.home
      value.to_s.start_with?(home) ? "~#{value.to_s.delete_prefix(home)}" : value.to_s
    end

    # Parse a search operand ("500M", "1.5G", "12 kB", "1h30m", "5") into the column's units.
    def parse(format, text)
      case format
      when :bytes, :bytes_per_sec
        m = text.strip.upcase.match(/\A([\d.]+)\s*([KMGT]?)I?B?\z/) or return nil
        m[1].to_f * UNITS[m[2]]
      when :si_bytes
        m = text.strip.upcase.match(/\A([\d.]+)\s*([KMGTPE]?)B?\z/) or return nil
        m[1].to_f * (1000**(m[2].empty? ? 0 : "KMGTPE".index(m[2]) + 1))
      when :duration then parse_duration(text)
      when *NUMERIC, :id
        Float(text.delete("%x"), exception: false)
      else
        text
      end
    end

    # Bare seconds ("90"), or unit parts: "90s", "5m", "2h", "1d", "1h30m", "250ms".
    def parse_duration(text)
      text = text.strip.downcase
      return Float(text, exception: false) if text.match?(/\A[\d.]+\z/)
      return nil unless text.match?(/\A(?:[\d.]+\s*(?:ms|[smhd])\s*)+\z/)

      text.scan(/([\d.]+)\s*(ms|[smhd])/).sum { |n, unit| Float(n, exception: false).to_f * SECONDS[unit] }
    end
  end
end
