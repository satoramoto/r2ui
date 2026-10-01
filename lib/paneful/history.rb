# frozen_string_literal: true

module Paneful
  # Recent values per (series id, attribute), for sparklines.
  class History
    def initialize(capacity: 120)
      @capacity = capacity
      @series = Hash.new { |h, k| h[k] = [] }
    end

    def record(id, key, value)
      list = @series[[id, key]]
      list << value.to_f
      list.shift while list.size > @capacity
    end

    def [](id, key) = @series.fetch([id, key], [])

    # Sum several series aligned at their newest value (for grouped lines).
    def sum(ids, key)
      lists = ids.map { |id| self[id, key] }.reject(&:empty?)
      return [] if lists.empty?

      len = lists.map(&:size).max
      Array.new(len) do |i|
        lists.sum { |l| l[l.size - len + i] || 0.0 }
      end
    end

    # Forget series whose ids are no longer present.
    def prune(live_ids)
      live = live_ids.to_set
      @series.delete_if { |(id, _), _| !live.include?(id) }
    end
  end
end
