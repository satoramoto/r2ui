# frozen_string_literal: true

# s26-progress: a progress bar in a panel (bubbles Progress).
#
#   R2UI.dashboard do
#     row height: 4 do
#       panel :status, resource: nil do
#         progress(:upload) { state[:sent].to_f / state[:size] }      # a fraction, 0.0..1.0
#         progress(:build, width: 30, gradient: ["#5A56E0", "#EE6FF8"], animate: true) { state[:built] }
#       end
#       panel :job do
#         progress :done, of: :total                                  # the record's done / total
#       end
#     end
#   end
#
# Hosts a `Bubbles::Progress` (`app.component(name)`) drawn on one line: the bar fills the
# panel's width (or `width:` columns) and ends with the percentage. The fraction comes from the
# block, run on a Context every frame, or with `of:` from the panel resource's first record
# (`done / total`, like the core `gauge`). Anything that isn't a finite number shows as 0;
# values are clamped to 0..1.
#
# `gradient: [from, to]` blends the fill between two colours. `animate: true` makes the bar
# spring towards the fraction (bubbles' animation) instead of jumping to it; the target is read
# after every update, so a change shows from the next message on.
module R2UI
  module Ext
    module Progress
      Item = Data.define(:name, :width, :gradient, :animate, :of, :block)

      module_function

      def build(item) = Bubbles::Progress.new(**{ width: item.width, gradient: item.gradient }.compact)

      # The fraction an item shows, in 0..1, read on `ctx` for an item in `panel`.
      def fraction(ctx, panel, item)
        value = item.block ? ctx.call(item.block) : from_record(ctx.app, panel, item)
        value = Float(value, exception: false) if value.is_a?(Numeric) || value.is_a?(String)
        value.is_a?(Float) && value.finite? ? value.clamp(0.0, 1.0) : 0.0
      end

      def from_record(app, panel, item)
        record = panel.resource && app.feeds[panel.resource]&.rows&.first
        return unless record

        resource = app.registry.resource(panel.resource)
        done, total = [item.name, item.of].map { |key| (resource.column(key) || DSL::Column.build(key)).read(record) }
        done.to_f / total.to_f if done.is_a?(Numeric) && total.is_a?(Numeric)
      end

      def instances(app) = app.components.select { |c| c.item.is_a?(Item) }
    end
  end

  extension :progress do
    dsl :panel do
      def progress(name, of: nil, width: nil, gradient: nil, animate: false, &block)
        raise ArgumentError, "progress #{name} needs a block or of:, not both" if block.nil? == of.nil?
        raise ArgumentError, "progress width must be a positive Integer" unless width.nil? || (width.is_a?(Integer) && width.positive?)
        raise ArgumentError, "progress gradient must be two colours" unless gradient.nil? || (gradient.is_a?(Array) && gradient.size == 2)

        R2UI::Component.require_bubbles!
        item(Ext::Progress::Item.new(name:, width:, gradient:, animate:, of:, block:))
      end
    end

    component(Ext::Progress::Item) { |item| Ext::Progress.build(item) }

    # Animated bars: retarget when the fraction changed; set_percent returns the animation's tick.
    after_update do
      Ext::Progress.instances(app).each do |c|
        next unless c.item.animate

        target = Ext::Progress.fraction(self, c.panel, c.item)
        command(c.model.set_percent(target)) if (target - c.model.percent).abs >= 0.001
      end
    end

    panel_item(Ext::Progress::Item) do |item|
      model = app.components.find { |c| c.item.equal?(item) }&.model || Ext::Progress.build(item)
      model.width = item.width || width
      item.animate ? model.view : model.view_as(Ext::Progress.fraction(self, panel, item))
    end
  end
end
