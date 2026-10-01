# frozen_string_literal: true

# s28-help: a panel showing the app's keys with bubbles' Help.
#
#   R2UI.dashboard do
#     on_key "r", help: "refresh" do refresh end
#     row do panel :deploys do table end end
#     row(height: 3) { panel(:keys, resource: nil) { help } }
#   end
#
# `help` draws `Bubbles::Help` short help ("? help • r refresh • tab panel • … • q quit") from
# `app.hint_pairs`: every extension's hints, then the core's. `?` toggles full help, which lays the
# same hints out in columns as tall as the panel. Both are cut to the panel's width. While a help
# panel is on the dashboard, `?` is bound (an ordinary binding, priority 0) and "? help" leads the
# hints. Needs the bubbles gem.
module R2UI
  module Ext
    module Help
      # What `help` adds to the panel.
      Item = Data.define

      # The keymap Bubbles::Help reads: one binding per [key, label] hint pair.
      Keymap = Data.define(:bindings, :column_height) do
        def short_help = bindings
        def full_help = bindings.each_slice(column_height).to_a
      end

      module_function

      def present?(dashboard) = dashboard.panels.any? { |panel| panel.items.any?(Item) }

      def keymap(pairs, column_height)
        bindings = pairs.map { |key, label| Bubbles::Key.binding(keys: [key], help: [key, label]) }
        Keymap.new(bindings:, column_height: [column_height, 1].max)
      end
    end
  end

  extension :help do
    dsl :panel do
      def help
        Component.require_bubbles!
        item(Ext::Help::Item.new)
      end
    end

    hints { [["?", "help"]] if Ext::Help.present?(dashboard) }

    on ->(msg) { msg.is_a?(Bubbletea::KeyMessage) && Keys.name(msg) == "?" } do
      pass unless Ext::Help.present?(dashboard)

      store(:help)[:full] = !store(:help)[:full]
    end

    panel_item Ext::Help::Item do
      help = Bubbles::Help.new
      help.width = width
      help.show_all = store(:help)[:full] ? true : false
      help.view(Ext::Help.keymap(app.hint_pairs(self), height))
    end
  end
end
