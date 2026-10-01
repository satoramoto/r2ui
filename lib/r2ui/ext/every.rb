# frozen_string_literal: true

# s01-every: repeating timers (Bubbletea's tick loop, declared).
#
#   R2UI.dashboard do
#     every 5 do                      # seconds, or anything with #to_f (5.seconds)
#       state[:checked_at] = Time.now
#       flash "checked"               # any Context helper; a returned command runs too
#     end
#   end
#
# Each timer starts when the app starts and fires every `seconds` until it quits. The block runs
# on the update thread (a Context), so it may touch app state freely.
#
# This is the reference extension: a story copies its shape (a DSL keyword that `declare`s plain
# data, an `init` hook that starts things, an `on` handler for its own message) and its test
# (test/ext/every_test.rb).
module R2UI
  module Ext
    module Every
      # What `every` declares on the dashboard.
      Timer = Data.define(:seconds, :block)

      # The message a timer's tick delivers. `app` scopes it to the app that scheduled it.
      # Messages subclass Bubbletea::Message: the runner only delivers those from background commands.
      class Tick < Bubbletea::Message
        attr_reader :timer, :app

        def initialize(timer:, app:)
          super()
          @timer = timer
          @app = app
        end
      end

      module_function

      # The command that delivers `timer`'s next Tick to `app`.
      def schedule(app, timer) = Bubbletea.tick(timer.seconds) { Tick.new(timer:, app:) }
    end
  end

  extension :every do
    dsl :dashboard do
      def every(seconds, &block)
        raise ArgumentError, "every needs a block" unless block

        seconds = seconds.to_f
        raise ArgumentError, "every needs a positive interval, got #{seconds}" unless seconds.positive?

        declare(:every, Ext::Every::Timer.new(seconds:, block:))
      end
    end

    init do
      dashboard.declared(:every).each { |timer| command(Ext::Every.schedule(app, timer)) }
    end

    on Ext::Every::Tick do |tick|
      pass unless tick.app.equal?(app)

      call(tick.timer.block)
      command(Ext::Every.schedule(app, tick.timer))
    end
  end
end
