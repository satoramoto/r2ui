# frozen_string_literal: true

module R2UI
  # Fetches one resource on its refresh interval in a background thread and records history.
  class Feed
    SINGLE = :record

    attr_reader :resource, :history

    # The feed for `resource`: a ServerFeed when its source takes a request.
    def self.for(resource) = resource.server? ? ServerFeed.new(resource) : new(resource)

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

    # What one panel draws from: this feed (ServerFeed returns a view of the panel's request).
    def view(_request = nil, _owner = nil) = self

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

    # Records numeric columns of `rows` in the history, then forgets ids not among `keep`'s rows.
    def record(rows, keep = [rows])
      return unless @resource.key || rows.size == 1

      numeric = @resource.columns.select(&:numeric?)
      rows.each do |row|
        id = series_id(row)
        numeric.each { |c| @history.record(id, c.key, c.read(row) || 0) }
      end
      @history.prune(keep.flat_map { |list| list.map { |row| series_id(row) } })
    end
  end

  # The feed of a server-side resource: one result per distinct Request the panels want, all
  # fetched by the same thread on the interval. `want` sets the requests; the App fetches new ones
  # at once (a background command calling `fetch`). A response is kept only while its request is
  # still wanted and only if no later-started fetch of it has landed, so a slow fetch for an old
  # search never replaces newer rows.
  class ServerFeed < Feed
    Slot = Struct.new(:rows, :error, :seq)

    # One panel's view of its request: what the renderer reads (rows, error, history, series_id).
    # Until the request's first response lands, rows are what that panel showed before (so changing
    # scope or search doesn't blank the table), or [].
    class View
      def initialize(feed, request, owner)
        @feed = feed
        @request = request
        @owner = owner
      end

      attr_reader :request

      def rows = @feed.rows_for(@request, @owner)
      def error = @feed.error_for(@request)
      def history = @feed.history
      def version = @feed.version
      def series_id(row) = @feed.series_id(row)
    end

    def initialize(resource)
      super
      @slots = {}
      @primary = nil
      @seq = 0
      @shown = {}
    end

    # The requests the panels show now, the first being the focused panel's. Returns the ones not
    # wanted before (to fetch now); results for requests dropped here are forgotten.
    def want(requests)
      requests = requests.uniq
      @lock.synchronize do
        added = requests.reject { |r| @slots.key?(r) }
        @slots = requests.to_h { |r| [r, @slots[r] || Slot.new(nil, nil, 0)] }
        @primary = requests.first
        added
      end
    end

    def requests = @lock.synchronize { @slots.keys }

    # The primary (focused panel's) request's rows and error, for code that asks the feed directly.
    def rows = rows_for(@lock.synchronize { @primary })
    def error = error_for(@lock.synchronize { @primary })

    def view(request, owner = nil) = View.new(self, request, owner)

    # Rows for `request`; nil-safe. With an `owner` (a panel), falls back to what it showed last.
    def rows_for(request, owner = nil)
      rows = @lock.synchronize { @slots[request]&.rows }
      return rows || [] unless owner

      rows ? (@shown[owner] = rows) : (@shown[owner] || [])
    end

    def error_for(request) = @lock.synchronize { @slots[request]&.error }

    # Fetches every wanted request (the interval, `refresh`, snapshots).
    def refresh! = requests.each { |request| fetch(request) }

    # Fetches one request. Returns true if its result was kept.
    def fetch(request)
      seq = @lock.synchronize { @seq += 1 }
      begin
        rows = @resource.fetch(request)
      rescue StandardError => e
        error = "#{e.class}: #{e.message}"
      end
      @lock.synchronize do
        slot = @slots[request]
        next false unless slot && seq > slot.seq

        slot.seq = seq
        slot.error = error
        unless error
          slot.rows = rows
          record(rows, @slots.values.filter_map(&:rows))
        end
        @version += 1
        true
      end
    end
  end
end
