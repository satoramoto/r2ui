# frozen_string_literal: true

# s27-paginator: one page of a list at a time, with a bubbles Paginator under it.
#
#   R2UI.dashboard do
#     row do
#       panel :deploys, resource: nil do
#         paginate :history, items: -> { DEPLOYS.last(200) }, per_page: 10 do |deploy|
#           "#{deploy[:sha]}  #{deploy[:status]}"
#         end
#       end
#     end
#   end
#
# `items:` is read on every frame (a plain call of the lambda, so it sees the variables around
# it); the block turns one item into its line and runs on a Context (state, helpers). Under the
# page the panel shows a `Bubbles::Paginator`: dots ("● ○ ○", the default) or "1/3" with
# `type: :arabic`. While the panel has focus, left/h and right/l change the page; other keys
# (tab, q, ...) carry on as usual. When the list shrinks the page is clamped to the last one;
# an empty list is one empty page. `component(:history)` is the Bubbles::Paginator.
module R2UI
  module Ext
    module Paginator
      Item = Data.define(:name, :items, :per_page, :type, :block)

      TYPES = %i[dots arabic].freeze
      STEPS = { left: -1, "h" => -1, right: 1, "l" => 1 }.freeze

      # Bubbles::Paginator has no `update`; the component host sends it the non-key messages.
      module Hosted
        def update(_message) = [self, nil]
      end

      module_function

      # Re-reads the items, resizes `paginator` to them (clamping the page) and returns them.
      def refresh(paginator, item)
        rows = Array(item.items.call)
        paginator.update_total_pages(rows.size)
        rows
      end

      def instance(app, item) = app.components.find { |c| c.item.equal?(item) }
    end
  end

  extension :paginator do
    dsl :panel do
      def paginate(name, items: nil, per_page: 10, type: :dots, &block)
        raise ArgumentError, "paginate needs items: -> { [...] }" unless items.respond_to?(:call)
        raise ArgumentError, "paginate needs a block that draws one item" unless block
        raise ArgumentError, "paginate per_page must be positive, got #{per_page}" unless per_page.to_i.positive?
        unless Ext::Paginator::TYPES.include?(type)
          raise ArgumentError, "paginate type must be one of #{Ext::Paginator::TYPES.join(", ")}, got #{type.inspect}"
        end

        Component.require_bubbles!
        item(Ext::Paginator::Item.new(name:, items:, per_page: per_page.to_i, type:, block:))
      end
    end

    component(Ext::Paginator::Item) do |item|
      paginator = Bubbles::Paginator.new(type: item.type, per_page: item.per_page).extend(Ext::Paginator::Hosted)
      Ext::Paginator.refresh(paginator, item)
      paginator
    end

    # Keys the focused panel's paginator handles itself (50: before ordinary bindings).
    on Bubbletea::KeyMessage, priority: 50 do |message|
      step = Ext::Paginator::STEPS[Keys.name(message)]
      hosted = step && app.components.find { |c| c.panel.equal?(focus) && c.item.is_a?(Ext::Paginator::Item) }
      pass unless hosted

      Ext::Paginator.refresh(hosted.model, hosted.item)
      step.positive? ? hosted.model.next_page : hosted.model.prev_page
    end

    panel_item(Ext::Paginator::Item) do |item|
      paginator = Ext::Paginator.instance(app, item).model
      rows = Ext::Paginator.refresh(paginator, item)
      from, to = paginator.slice_bounds(rows.size)
      lines = rows[from...to].map { |row| call(item.block, row).to_s }
      (lines.first([height - 1, 0].max) + [paginator.view]).join("\n")
    end
  end
end
