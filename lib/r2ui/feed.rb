# frozen_string_literal: true

module R2UI
  # Fetches one resource on its refresh interval in a background thread and records history.
  # A resource reading a shared source (`source from:`) gets it through `sources` (R2UI::Sources).
  class Feed
    SINGLE = :record

    attr_reader :resource, :history

    def initialize(resource, sources: nil)
      @resource = resource
      @sources = sources
      @history = History.new(capacity: resource.history_size)
      @lock = Mutex.new
      @rows = []
      @error = nil
      @version = 0
    end

    def rows = @lock.synchronize { @rows }
    def error = @lock.synchronize { @error }
    def version = @lock.synchronize { @version }

    # Seconds between fetches: the resource's `refresh every:`, else its shared source's interval,
    # else 1.
    def interval
      return @resource.refresh_interval if @resource.refresh_interval
      return @sources.interval(@resource.source_from) if @resource.source_from && @sources

      @resource.interval
    end

    # History id for a row: its key, or :record when the resource returns a single record.
    def series_id(row) = @resource.key ? @resource.identify(row) : SINGLE

    def start(&on_update)
      @thread = Thread.new do
        loop do
          refresh!
          on_update&.call
          sleep interval
        end
      end
      self
    end

    def stop
      @thread&.kill
      @thread&.join(1)
    end

    # Fetches now. `expire: true` also drops a shared source's cached value first (a manual
    # refresh wants new data, not the value another feed fetched a moment ago).
    def refresh!(expire: false)
      @sources.expire(@resource.source_from) if expire && @resource.source_from && @sources
      rows = @resource.fetch(@sources)
      @lock.synchronize do
        record(rows)
        @rows = rows
        @error = nil
        @version += 1
      end
    rescue StandardError => e
      @lock.synchronize do
        @error = "#{e.class}: #{e.message}"
        @version += 1
      end
    end

    private

    def record(rows)
      return unless @resource.key || rows.size == 1

      numeric = @resource.columns.select(&:numeric?)
      ids = rows.map do |row|
        id = series_id(row)
        numeric.each { |c| @history.record(id, c.key, c.read(row) || 0) }
        id
      end
      @history.prune(ids)
    end
  end
end
