# frozen_string_literal: true

# s28-help: a panel showing the app's keys, as bubbles' Help draws them.
#
#   R2UI.dashboard do
#     on_key "r", help: "refresh" do refresh end
#     row do panel :deploys do table end end
#     row(height: 3) { panel(:keys, resource: nil) { help } }
#   end
#
# `help` draws short help ("? help • r refresh • tab panel • … • q quit") from `app.hint_pairs`:
# every extension's hints, then the core's (what the status bar shows). `?` toggles full help,
# which lists `app.key_pairs` (the hints plus the focused table's actions and the navigation keys)
# in columns as tall as the panel. Both are cut to the panel's width. While a help panel is on the
# dashboard, `?` is bound (an ordinary binding, priority 0) and "? help" leads the hints.
#
# With the bubbles gem it draws through Bubbles::Help; without it, it draws the same text itself
# (Ext::Help.render), so bubbles is optional here.
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

      SHORT_SEPARATOR = " • "
      FULL_SEPARATOR = "    "

      module_function

      def present?(dashboard) = dashboard.panels.any? { |panel| panel.items.any?(Item) }

      def keymap(pairs, column_height)
        bindings = pairs.map { |key, label| Bubbles::Key.binding(keys: [key], help: [key, label]) }
        Keymap.new(bindings:, column_height: [column_height, 1].max)
      end

      # What Bubbles::Help#view draws for `keymap(pairs, column_height)` with `width` and
      # `show_all: full`, without the bubbles gem: short help joins "key label" with " • "; full
      # help puts columns of `column_height` side by side (each row's cells joined with four
      # spaces); every line is cut to `width` (0: no limit). Pairs with an empty key or label are
      # left out.
      def render(pairs, width:, column_height:, full: false)
        return render_short(pairs, width) unless full

        columns = pairs.each_slice([column_height, 1].max).map { |group| entries(group) }.reject(&:empty?)
        return "" if columns.empty?

        rows = Array.new(columns.map(&:size).max) { |i| columns.map { |col| col[i] || "" }.join(FULL_SEPARATOR) }
        truncate(rows.join("\n"), width)
      end

      def render_short(pairs, width)
        parts = entries(pairs)
        parts.empty? ? "" : truncate(parts.join(SHORT_SEPARATOR), width)
      end

      def entries(pairs)
        pairs.filter_map do |key, label|
          next if key.nil? || key.to_s.empty? || label.nil? || label.to_s.empty?

          "#{key} #{label}"
        end
      end

      def truncate(text, width)
        return text if width <= 0

        text.split("\n").map { |line| line.length > width ? line[0, width] : line }.join("\n")
      end
    end
  end

  extension :help do
    dsl :panel do
      def help
        Component.bubbles? # loads bubbles when it's there; the panel draws without it too
        item(Ext::Help::Item.new)
      end
    end

    hints { [["?", "help"]] if Ext::Help.present?(dashboard) }

    on ->(msg) { msg.is_a?(Bubbletea::KeyMessage) && Keys.name(msg) == "?" } do
      pass unless Ext::Help.present?(dashboard)

      store(:help)[:full] = !store(:help)[:full]
    end

    panel_item Ext::Help::Item do
      full = store(:help)[:full] ? true : false
      pairs = full ? app.key_pairs(self) : app.hint_pairs(self)
      if Component.bubbles?
        help = Bubbles::Help.new
        help.width = width
        help.show_all = full
        help.view(Ext::Help.keymap(pairs, height))
      else
        Ext::Help.render(pairs, width:, column_height: height, full:)
      end
    end
  end
end
