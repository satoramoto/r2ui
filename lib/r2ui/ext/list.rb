# frozen_string_literal: true

# s22-list: a bubbles List in a panel (browse, filter with `/`, pick with enter).
#
#   R2UI.dashboard do
#     row do
#       panel :fruit, resource: nil do
#         list :fruit, items: -> { state[:fruits] }, title: "Fruit",
#                      on_select: ->(fruit) { flash "picked #{fruit}" }
#       end
#       panel :process do
#         list :procs, resource: :process, label: :name, filter: true,
#                      on_select: ->(row) { state[:pid] = row.pid }
#       end
#     end
#   end
#
# Options:
# - `items:` a lambda returning the items, re-read on every frame (it runs on a Context, so it can
#   read `state`); or `resource:` a resource name, whose latest rows are the items (some panel
#   must show that resource, so its feed runs). Give exactly one.
# - `title:` the list's title line; without it the list shows no title (the panel has one).
# - `filter:` (default true) whether `/` starts filtering; false turns filtering off.
# - `label:` how an item reads: an attribute name (`:name`) or a lambda (`->(item) { ... }`).
#   Without it, bubbles' own rule applies: `title`, then a Hash's `:title`, then `to_s`. Filtering
#   matches the same text.
# - `on_select:` called with the selected item (the original item or row, not its label) when
#   enter is pressed; it runs on a Context, so it can touch `state`, `flash`, return commands.
#
# The list is a `Bubbles::List`, sized to the panel on every frame, and takes keys while its
# panel has focus (tab and shift+tab still move focus): up/down/k/j, home/end/g/G, pgup/pgdown,
# `/` to filter (enter applies, esc clears). Item changes keep the selection and the filter.
# `component(:name)` gives the `Bubbles::List`.
module R2UI
  module Ext
    module List
      Item = Data.define(:name, :items, :resource, :title, :filter, :label, :on_select)

      # What the list holds when `label:` is given: bubbles shows and filters by `title`.
      Entry = Data.define(:item, :title)

      module_function

      def build(item)
        Component.require_bubbles!
        list = Bubbles::List.new([], width: 0, height: 1)
        list.title = item.title.to_s
        list.show_title = !item.title.nil?
        list.show_filter = item.filter
        list
      end

      # The current items: from the lambda or the resource's feed, mapped through `label:`.
      def source(ctx, item)
        raw = if item.resource
                feed = ctx.app.feeds[item.resource]
                raise Error, "list #{item.name}: no panel shows resource #{item.resource.inspect}" unless feed

                feed.rows
              else
                ctx.call(item.items)
              end
        Array(raw)
      end

      def entries(ctx, item, raw)
        case item.label
        when nil then raw
        when Symbol, String then raw.map { |r| Entry.new(item: r, title: Value.fetch(r, item.label.to_sym).to_s) }
        else raw.map { |r| Entry.new(item: r, title: ctx.call(item.label, r).to_s) }
        end
      end

      # Gives `list` new items, keeping its filter (state and text) and selection; bubbles'
      # `items=` alone would clear both.
      def replace(list, items)
        filter_state = list.filter_state
        query = list.filter_input.value
        selected = list.selected_index

        list.items = items
        unless filter_state == Bubbles::List::UNFILTERED
          list.start_filtering
          list.filter_input.value = query
          list.apply_filter
          list.start_filtering if filter_state == Bubbles::List::FILTERING
        end
        list.select(selected)
      end

      def resize(list, width, height)
        return if list.width == width && list.height == height

        list.width = width
        list.height = height
        list.select(list.selected_index) # keeps the selection in view
        list.update(Bubbletea::Message.new) # bubbles recounts its pages in update
      end

      def unwrap(entry) = entry.is_a?(Entry) ? entry.item : entry
    end
  end

  extension :list do
    dsl :panel do
      def list(name, items: nil, resource: nil, title: nil, filter: true, label: nil, on_select: nil)
        raise ArgumentError, "list #{name} needs `items:` or `resource:`, not both" unless items.nil? ^ resource.nil?
        raise ArgumentError, "list #{name}: `items:` must be callable" if items && !items.respond_to?(:call)

        item(Ext::List::Item.new(name:, items:, resource: resource&.to_sym, title:, filter:, label:, on_select:))
      end
    end

    component(Ext::List::Item, focusable: true) { |item| Ext::List.build(item) }

    panel_item(Ext::List::Item) do |item|
      instance = app.components.find { |c| c.item.equal?(item) && c.panel == panel }
      next "" unless instance

      list = instance.model
      raw = Ext::List.source(self, item)
      shown = (store(:list)[:shown] ||= {}.compare_by_identity)
      unless shown.key?(item) && shown[item] == raw
        Ext::List.replace(list, Ext::List.entries(self, item, raw))
        shown[item] = raw.dup # a copy: the lambda may hand back the same array, changed in place
      end
      Ext::List.resize(list, width, height)
      list.view
    end

    # Enter picks the selected item, unless the list is typing a filter (then bubbles applies it).
    on Bubbletea::KeyMessage, priority: 50 do |msg|
      pass unless Keys.name(msg) == :enter

      instance = app.components.find do |c|
        c.focused && c.panel == app.focus && c.item.is_a?(Ext::List::Item)
      end
      pass unless instance
      pass if instance.model.filter_state == Bubbles::List::FILTERING

      selected = instance.model.selected_item
      call(instance.item.on_select, Ext::List.unwrap(selected)) if selected && instance.item.on_select
    end
  end
end
