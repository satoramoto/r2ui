# frozen_string_literal: true

# s23-data-table: a bubbles Table in a panel.
#
#   R2UI.dashboard do
#     row height: 12 do
#       panel :services, resource: nil do
#         data_table :services,
#                    columns: [["Name", 20], ["Count", 5]],      # [title, width], ...
#                    rows: -> { state[:services] || [] },        # Array of Arrays, read every frame
#                    on_select: ->(row) { flash "picked #{row.first}" }
#       end
#     end
#   end
#
# The panel hosts a `Bubbles::Table` (`component(:services)` returns it). Its height follows the
# panel, and `rows` (run on a Context) is re-read on every frame. While the panel has focus the
# table takes its keys (up/down, j/k, pgup/pgdown, home/end, as bubbles defines them); enter calls
# `on_select` with the row under the cursor. Needs the bubbles gem.
module R2UI
  module Ext
    module DataTable
      Item = Data.define(:name, :columns, :rows, :on_select)

      # Rows for the header and the separator under it.
      CHROME = 2

      module_function

      def enter?(message) = message.is_a?(Bubbletea::KeyMessage) && Keys.name(message) == :enter

      def columns(item) = item.columns.map { |title, width| { title: title.to_s, width: Integer(width) } }
    end
  end

  extension :data_table do
    dsl :panel do
      def data_table(name = nil, columns: nil, rows: nil, on_select: nil)
        raise ArgumentError, "data_table needs a name" unless name
        raise ArgumentError, "data_table needs columns: [[title, width], ...]" if columns.nil? || columns.empty?
        raise ArgumentError, "data_table needs rows: -> { [...] }" unless rows.respond_to?(:call)

        R2UI::Component.require_bubbles!
        item(Ext::DataTable::Item.new(name: name.to_sym, columns:, rows:, on_select:))
      end
    end

    component(Ext::DataTable::Item, focusable: true) do |item|
      Bubbles::Table.new(columns: Ext::DataTable.columns(item), rows: Array(call(item.rows)))
    end

    panel_item(Ext::DataTable::Item) do |item|
      table = component(item.name)
      table.height = [height - Ext::DataTable::CHROME, 1].max
      table.rows = Array(call(item.rows))
      table.view
    end

    # Enter on a focused table selects its row; runs before the table itself (which ignores enter).
    on(->(message) { Ext::DataTable.enter?(message) }, priority: 50) do
      item = focus&.items&.find { |i| i.is_a?(Ext::DataTable::Item) }
      table = item && component(item.name)
      pass unless table&.focused? && item.on_select

      row = table.selected_row_data
      pass unless row

      call(item.on_select, row)
    end
  end
end
