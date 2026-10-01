# frozen_string_literal: true

module R2UI
  module DSL
    Gauge = Data.define(:attr, :of, :label)
    Stat = Data.define(:attrs)
    Sparkline = Data.define(:attr, :label, :height)
    Table = Data.define(:scope, :group_by, :sort, :limit)

    # `resource` is nil for a panel that shows only extension items (a text input, a spinner, ...).
    # `options` holds keyword options the core doesn't know, for extensions to read.
    Panel = Data.define(:name, :resource, :span, :title, :items, :options) do
      def table = items.find { |i| i.is_a?(Table) }
    end

    Row = Data.define(:height, :panels)

    # A screen made of rows of panels. Each panel shows one resource.
    # Extensions record their own declarations (timers, key bindings, ...) under `declarations`.
    class Dashboard
      attr_reader :name, :title, :rows, :declarations

      def self.build(name, &block)
        dashboard = new(name)
        Builder.new(dashboard).instance_eval(&block) if block
        dashboard
      end

      # A one-panel dashboard showing a resource's full index.
      def self.for_resource(resource)
        build(resource.name) { row { panel resource.name } }
      end

      def initialize(name)
        @name = name.to_sym
        @title = name.to_s.tr("_", " ").capitalize
        @rows = []
        @declarations = Hash.new { |h, k| h[k] = [] }
      end

      def panels = rows.flat_map(&:panels)

      # Everything an extension declared under `key`, in order ([] if none).
      def declared(key) = declarations.fetch(key, [])

      class Builder
        def initialize(dashboard) = @d = dashboard

        def title(text) = @d.instance_variable_set(:@title, text)

        # `height:` in terminal lines; rows without one share the remaining space.
        def row(height: nil, &block)
          builder = RowBuilder.new
          builder.instance_eval(&block)
          @d.rows << Row.new(height:, panels: builder.panels)
        end

        private

        # For extension keywords: record `value` under `key` on the dashboard. Returns `value`.
        def declare(key, value)
          @d.declarations[key] << value
          value
        end
      end

      class RowBuilder
        attr_reader :panels

        def initialize = @panels = []

        # `span:` is a relative width; panels in a row split it by their spans.
        # `resource: nil` makes a panel with no data source (extension items only).
        def panel(name, resource: name, span: 1, title: nil, **options, &block)
          items = PanelBuilder.new.tap { |b| b.instance_eval(&block) if block }.items
          if items.empty?
            raise Error, "panel #{name} has no resource and nothing to show" unless resource

            items = [Table.new(scope: nil, group_by: nil, sort: nil, limit: nil)]
          end
          @panels << Panel.new(name:, resource:, span:, title:, items:, options:)
        end
      end

      class PanelBuilder
        attr_reader :items

        def initialize = @items = []

        def gauge(attr, of:, label: nil) = @items << Gauge.new(attr:, of:, label:)

        def stat(*attrs) = @items << Stat.new(attrs:)

        def sparkline(attr, label: nil, height: 3) = @items << Sparkline.new(attr:, label:, height:)

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
