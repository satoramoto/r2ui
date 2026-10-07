# frozen_string_literal: true

module ActiveR2UI
  # A datetime or date column's value: shown relative to now ("3m ago", "in 2h"; the date itself
  # past 30 days), compared by time. It is a Numeric so r2ui's sort orders it by time, not by its
  # text; its text is recomputed each frame, so ages stay current.
  class Timestamp < Numeric
    RELATIVE_LIMIT = 30 * 86_400

    attr_reader :value

    def initialize(value)
      super()
      @value = value
    end

    def self.wrap(value) = value.nil? ? nil : new(value)

    def to_time = value.to_time

    def to_f = to_time.to_f

    def <=>(other) = other.is_a?(Timestamp) ? to_f <=> other.to_f : nil

    def ==(other) = other.is_a?(Timestamp) && to_f == other.to_f
    alias eql? ==

    def hash = to_f.hash

    def to_s(now = Time.now)
      date? ? date_text(now.to_date) : time_text(now)
    end
    alias inspect to_s

    private

    def date? = value.is_a?(Date) && !value.is_a?(DateTime)

    def date_text(today)
      days = (today - value).to_i
      return value.iso8601 if days.abs > 30
      return "today" if days.zero?

      days.positive? ? "#{days}d ago" : "in #{-days}d"
    end

    def time_text(now)
      seconds = now - to_time
      return to_time.strftime("%Y-%m-%d") if seconds.abs > RELATIVE_LIMIT

      span = duration(seconds.abs)
      seconds.negative? ? "in #{span}" : "#{span} ago"
    end

    def duration(seconds)
      if seconds < 60 then "#{seconds.floor}s"
      elsif seconds < 3600 then "#{(seconds / 60).floor}m"
      elsif seconds < 86_400 then "#{(seconds / 3600).floor}h"
      else "#{(seconds / 86_400).floor}d"
      end
    end
  end
end
