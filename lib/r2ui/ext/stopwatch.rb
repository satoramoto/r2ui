# frozen_string_literal: true

# s30-stopwatch: an elapsed-time counter (bubbles' Stopwatch) as a panel item.
#
#   R2UI.dashboard do
#     row height: 3 do
#       panel :lap, resource: nil do
#         stopwatch :lap                    # starts counting when the app starts
#         # stopwatch :lap, autostart: false  # waits for `s`
#       end
#     end
#   end
#
# The panel shows the elapsed time ("0:42.00", "1:02:03.00" past an hour), counting in whole
# seconds. While the panel is focused, `s` starts or stops it and `r` resets it to zero; other keys
# go on to your bindings and the core as usual. `component(:lap)` is the Bubbles::Stopwatch, for
# reading `elapsed` / `running?` or sending its `start`, `stop`, `toggle` and `reset` commands.
#
# Needs the bubbles gem (it is loaded the first time `stopwatch` is used).
module R2UI
  module Ext
    module Stopwatch
      Item = Data.define(:name, :autostart)

      HINTS = [%w[s start/stop], %w[r reset]].freeze

      module_function

      def build(item)
        model = Bubbles::Stopwatch.new
        model.define_singleton_method(:init) { nil } unless item.autostart
        model
      end

      # The stopwatch hosted in the focused panel, if any.
      def focused(app)
        app.components.find { |c| c.item.is_a?(Item) && c.panel == app.focus }&.model
      end
    end
  end

  extension :stopwatch do
    dsl :panel do
      def stopwatch(name, autostart: true)
        raise ArgumentError, "stopwatch needs a Symbol name, got #{name.inspect}" unless name.is_a?(Symbol)

        Component.require_bubbles!
        item(Ext::Stopwatch::Item.new(name:, autostart:))
      end
    end

    component(Ext::Stopwatch::Item) { |item| Ext::Stopwatch.build(item) }

    on Bubbletea::KeyMessage, priority: 50 do |message|
      watch = Ext::Stopwatch.focused(app)
      pass unless watch

      case Keys.name(message)
      when "s" then command(watch.toggle)
      when "r" then command(watch.reset)
      else pass
      end
    end

    hints { focus.items.any?(Ext::Stopwatch::Item) ? Ext::Stopwatch::HINTS : [] }
  end
end
