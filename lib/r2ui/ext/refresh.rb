# frozen_string_literal: true

# s19-refresh: fetch a resource now instead of waiting for its interval.
#
#   R2UI.dashboard do
#     on_key "r", help: "refresh" do refresh end   # the focused panel's resource
#     every 60 do refresh(:process) end             # a resource by name
#   end
#
# `refresh` is a helper for any handler or user block. It enqueues a background command that
# fetches the resource once (the same fetch its interval runs, history included), so the update
# thread never waits on the source; the next frame shows the new rows. The interval keeps running
# as before. `refresh(:name)` refreshes that resource; an unknown name (one no panel shows) raises
# ArgumentError. Plain `refresh` uses the focused panel's resource and just flashes "nothing to
# refresh" when that panel has none. Returns the command.
module R2UI
  module Ext
    module Refresh
      module_function

      # The feed `refresh` targets: the named one, or the focused panel's.
      def feed(app, name)
        if name.nil?
          name = app.focus&.resource
          return unless name
        end
        app.feeds.fetch(name.to_sym) do
          raise ArgumentError, "refresh: unknown resource #{name.inspect} (known: #{app.feeds.keys.join(", ")})"
        end
      end

      # The background command that fetches `feed` once. It delivers no message: the frame reads
      # the feed's rows directly.
      def command(feed)
        proc do
          feed.refresh!(expire: true)
          nil
        end
      end
    end
  end

  extension :refresh do
    helpers do
      def refresh(name = nil)
        feed = Ext::Refresh.feed(app, name)
        if feed
          command(Ext::Refresh.command(feed))
        else
          flash("nothing to refresh")
          nil
        end
      end
    end
  end
end
