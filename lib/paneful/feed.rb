# frozen_string_literal: true

module Paneful
  # Fetches one resource on its refresh interval in a background thread and records history.
  class Feed
    SINGLE = :record

    attr_reader :resource, :history

    def initialize(resource)
      @resource = resource
      @history = History.new
      @lock = Mutex.new
      @rows = []
      @error = nil
      @version = 0
    end

    def rows = @lock.synchronize { @rows }
    def error = @lock.synchronize { @error }
    def version = @lock.synchronize { @version }

    # History id for a row: its key, or :record when the resource returns a single record.
    def series_id(row) = @resource.key ? @resource.identify(row) : SINGLE

    def start(&on_update)
      @thread = Thread.new do
        loop do
          refresh!
          on_update&.call
          sleep @resource.interval
        end
      end
      self
    end

    def stop
      @thread&.kill
      @thread&.join(1)
    end

    def refresh!
      rows = @resource.fetch
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
