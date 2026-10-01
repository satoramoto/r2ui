# frozen_string_literal: true

module R2UI
  # The shared sources of one app (R2UI.source): each is fetched at most once per interval
  # (precisely: a value younger than 3/4 of the interval is reused), however many resources read
  # it with `source from: :name`. Feeds call `value` from their own threads; one lock per source.
  #
  #   R2UI.source(:sample, every: 2) { |previous| Probe.sample(previous) }
  #   R2UI.resource(:process) { source(from: :sample) { |s| s[:processes] } }
  #   R2UI.resource(:memory)  { source(from: :sample) { |s| s[:memory] } }
  #
  # The block gets the previous value (nil the first time), for rates. An error is kept for the
  # same window as a value, so a failing source isn't retried by every feed.
  class Sources
    REUSE = 0.75

    def initialize(registry, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @registry = registry
      @clock = clock
      @entries = {}
      @lock = Mutex.new
    end

    # The source's current value, fetching it if the cached one is too old. Raises what the
    # source's block raised.
    def value(name) = entry(name).value(@clock.call)

    def interval(name) = @registry.source(name).interval

    # Drops the cached value, so the next `value` fetches.
    def expire(name) = entry(name).expire

    private

    def entry(name)
      @lock.synchronize { @entries[name.to_sym] ||= Entry.new(@registry.source(name)) }
    end

    class Entry
      def initialize(source)
        @source = source
        @lock = Mutex.new
        @at = nil
      end

      def value(now)
        @lock.synchronize do
          fetch(now) if @at.nil? || now - @at >= @source.interval * REUSE
          raise @error if @error

          @value
        end
      end

      def expire = @lock.synchronize { @at = nil }

      private

      def fetch(now)
        previous = @value
        @value = @source.block.call(previous)
        @error = nil
      rescue StandardError => e
        @error = e
      ensure
        @at = now
      end
    end
  end
end
