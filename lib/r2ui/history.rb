# frozen_string_literal: true

module R2UI
  # Recent values per (series id, attribute), for sparklines. Keeps `capacity` points per series.
  # A series whose row disappears is kept for `capacity` more samples, so a row that comes back
  # (or a row an app keeps showing from its own data) continues its line instead of starting over.
  class History
    attr_reader :capacity

    def initialize(capacity: 120)
      raise ArgumentError, "capacity must be positive" unless capacity.positive?

      @capacity = capacity
      @series = Hash.new { |h, k| h[k] = [] }
      @seen = {}
      @samples = 0
    end

    def record(id, key, value)
      list = @series[[id, key]]
      list << value.to_f
      list.shift while list.size > @capacity
    end

    def [](id, key) = @series.fetch([id, key], [])

    # Sum several series aligned at their newest value (for grouped lines).
    def self.sum(lists)
      lists = lists.reject(&:empty?)
      return [] if lists.empty?

      len = lists.map(&:size).max
      Array.new(len) do |i|
        lists.sum do |l|
          at = l.size - len + i
          at.negative? ? 0.0 : l[at] # a shorter series hasn't started yet (a negative index would wrap)
        end
      end
    end

    def sum(ids, key) = History.sum(ids.map { |id| self[id, key] })

    # Called once per sample with the ids present in it: forgets series whose ids haven't been
    # seen for `capacity` samples.
    def prune(live_ids)
      @samples += 1
      live_ids.each { |id| @seen[id] = @samples }
      stale = @seen.select { |_, at| @samples - at >= @capacity }.keys.to_set
      return if stale.empty?

      stale.each { |id| @seen.delete(id) }
      @series.delete_if { |(id, _), _| stale.include?(id) }
    end
  end
end
