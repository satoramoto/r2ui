# frozen_string_literal: true

# s29-timer: a countdown in a panel (a hosted Bubbles::Timer).
#
#   R2UI.dashboard do
#     row height: 3 do
#       panel :clock, resource: nil do
#         countdown :deadline, 90, on_timeout: -> { flash "time's up" }   # seconds, or anything with #to_f
#       end
#     end
#   end
#
# The timer starts when the app starts, ticks once a second and shows the time left ("1m30s",
# "5s", "0s"). When it ends, `on_timeout` runs once on the update thread (a Context: state, flash,
# quit, ...); a command it returns runs too. `component(:deadline)` is the Bubbles::Timer, so a
# block can `command(component(:deadline).stop)` / `.start` / `.toggle` it.
#
# Needs the bubbles gem (optional for apps).
module R2UI
  module Ext
    module Countdown
      # What `countdown` adds to the panel.
      Item = Data.define(:name, :seconds, :on_timeout)

      # Matches a Bubbles::Timer::TimeoutMessage without naming Bubbles at load time.
      TIMEOUT = ->(msg) { defined?(::Bubbles::Timer::TimeoutMessage) && msg.is_a?(::Bubbles::Timer::TimeoutMessage) }
    end
  end

  extension :countdown do
    dsl :panel do
      def countdown(name, seconds, on_timeout: nil)
        seconds = seconds.to_f
        raise ArgumentError, "countdown needs a positive duration, got #{seconds}" unless seconds.positive?

        Component.require_bubbles!
        item(Ext::Countdown::Item.new(name:, seconds:, on_timeout:))
      end
    end

    component(Ext::Countdown::Item) { |item| Bubbles::Timer.new(item.seconds) }

    observe Ext::Countdown::TIMEOUT do |msg|
      instance = app.components.find { |c| c.item.is_a?(Ext::Countdown::Item) && c.model.id == msg.id }
      fired = (store(:countdown)[:fired] ||= {})
      if instance && !fired[msg.id]
        fired[msg.id] = true
        call(instance.item.on_timeout) if instance.item.on_timeout
      end
    end
  end
end
