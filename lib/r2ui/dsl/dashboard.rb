# frozen_string_literal: true

module R2UI
  module DSL
    Gauge = Data.define(:attr, :of, :label)
    Stat = Data.define(:attrs)
    # `series:` plots a series the record carries (an attribute holding an Array, or a lambda
    # given the record) instead of the feed's history of `attr`.
    Sparkline = Data.define(:attr, :label, :height, :series) do
      def initialize(attr:, label: nil, height: 3, series: nil) = super
    end
    Table = Data.define(:scope, :group_by, :sort, :limit)

    # `resource` is nil for a panel that shows only extension items (a text input, a spinner, ...).
    # `options` holds keyword options the core doesn't know, for extensions to read.
    # `width` is a fixed width in columns (nil: share the row by `span`).
    Panel = Data.define(:name, :resource, :span, :title, :items, :options, :width) do
      def initialize(name:, resource:, span: 1, title: nil, items: [], options: {}, width: nil) = super

      def table = items.find { |i| i.is_a?(Table) }
    end

    # `name` lets other files add panels to the row (`row :top do ... end` again, or R2UI.panel).
    # Rows are drawn by `order`, then in the order they were first declared.
    Row = Data.define(:height, :panels, :name, :order) do
      def initialize(height: nil, panels: [], name: nil, order: 0) = super
    end

    # A screen made of rows of panels. Each panel shows one resource.
    # Extensions record their own declarations (timers, key bindings, ...) under `declarations`.
    #
    # A dashboard can be assembled from several files: R2UI.dashboard(name, extend: true) and
    # R2UI.panel run more blocks on the same Builder (see Registry).
    class Dashboard
      attr_reader :name, :title, :declarations
      # The name of the panel that has focus when the app starts (`focus :process`), or nil.
      attr_reader :initial_focus

      def self.build(name, &block)
        dashboard = new(name)
        dashboard.apply(&block)
      end

      # A one-panel dashboard showing a resource's full index.
      def self.for_resource(resource)
        build(resource.name) { row { panel resource.name } }
      end

      def initialize(name)
        @name = name.to_sym
        @title = name.to_s.tr("_", " ").capitalize
        @rows = []
        @panel_orders = {}
        @initial_focus = nil
        @declarations = Hash.new { |h, k| h[k] = [] }
      end

      def initialize_copy(source)
        super
        @rows = source.instance_variable_get(:@rows).dup
        @panel_orders = source.instance_variable_get(:@panel_orders).dup
        @declarations = Hash.new { |h, k| h[k] = [] }
        source.declarations.each { |k, v| @declarations[k] = v.dup }
      end

      # Runs a definition block on this dashboard's Builder. Returns self.
      def apply(&block)
        Builder.new(self).instance_eval(&block) if block
        self
      end

      # Rows by `order`, then declaration order. A row no file put a panel in takes no space.
      def rows = @rows.each_with_index.sort_by { |row, i| [row.order, i] }.map(&:first).reject { |r| r.panels.empty? }

      def panels = rows.flat_map(&:panels)

      def panel(name) = panels.find { |p| p.name == name.to_sym }

      # Everything an extension declared under `key`, in order ([] if none).
      def declared(key) = declarations.fetch(key, [])

      # --- used by the builders ---

      # Adds panels to the row named `name` (a new row when there's none, or when `name` is nil).
      # `height`/`order` change an existing row only when given. Panels go in by their `order`
      # (stable). A panel name already on the dashboard is an error.
      def add_row(name:, height:, order:, panels:)
        index = name && @rows.index { |r| r.name == name }
        row = index ? @rows[index] : Row.new(name:, height:, order: order || 0)
        row = row.with(height:) if index && height
        row = row.with(order:) if index && order
        members = row.panels.dup
        panels.each do |panel, panel_order|
          raise Error, "dashboard #{@name}: panel #{panel.name} is already defined" if self.panel(panel.name) || members.any? { |p| p.name == panel.name }

          @panel_orders[panel.name] = panel_order
          at = members.index { |p| @panel_orders.fetch(p.name, 0) > panel_order } || members.size
          members.insert(at, panel)
        end
        row = row.with(panels: members)
        index ? @rows[index] = row : @rows << row
        row
      end

      class Builder
        def initialize(dashboard) = @d = dashboard

        def title(text) = @d.instance_variable_set(:@title, text)

        # The panel that has focus (takes keys) when the app starts. Default: the first panel with
        # a table, else the first panel.
        def focus(panel_name) = @d.instance_variable_set(:@initial_focus, panel_name.to_sym)

        # `height:` in terminal lines; rows without one share the remaining space. A `name` lets
        # later blocks (other files) add panels to the same row: `row :top do panel ... end`.
        # `order:` places the row (default 0; equal orders keep declaration order).
        def row(name = nil, height: nil, order: nil, &block)
          builder = RowBuilder.new
          builder.instance_eval(&block) if block
          @d.add_row(name: name&.to_sym, height:, order:, panels: builder.entries)
        end

        private

        # For extension keywords: record `value` under `key` on the dashboard. Returns `value`.
        def declare(key, value)
          @d.declarations[key] << value
          value
        end
      end

      class RowBuilder
        # [panel, order] pairs, in the order declared.
        attr_reader :entries

        def initialize = @entries = []

        def panels = entries.map(&:first)

        # `span:` is a relative width; panels in a row split it by their spans. `width:` is a fixed
        # width in columns instead. `resource: nil` makes a panel with no data source (extension
        # items only). `order:` places it in its row (default 0; equal orders keep declaration order).
        def panel(name, resource: name, span: 1, title: nil, width: nil, order: 0, **options, &block)
          items = PanelBuilder.new.tap { |b| b.instance_eval(&block) if block }.items
          if items.empty?
            raise Error, "panel #{name} has no resource and nothing to show" unless resource

            items = [Table.new(scope: nil, group_by: nil, sort: nil, limit: nil)]
          end
          @entries << [Panel.new(name: name.to_sym, resource:, span:, title:, items:, options:, width:), order]
        end
      end

      class PanelBuilder
        attr_reader :items

        def initialize = @items = []

        def gauge(attr, of:, label: nil) = @items << Gauge.new(attr:, of:, label:)

        def stat(*attrs) = @items << Stat.new(attrs:)

        # `series:` an attribute (or lambda given the record) holding the values to plot, instead
        # of the history r2ui keeps for `attr`.
        def sparkline(attr, label: nil, height: 3, series: nil) = @items << Sparkline.new(attr:, label:, height:, series:)

        def table(scope: nil, group_by: nil, sort: nil, limit: nil)
          @items << Table.new(scope:, group_by:, sort:, limit:)
        end

        private

        # For extension keywords: add an item (any object) to the panel. Returns it.
        def item(value)
          @items << value
          value
        end
      end
    end
  end
end
