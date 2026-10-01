# frozen_string_literal: true

module Paneful
  module DSL
    Gauge = Data.define(:attr, :of, :label)
    Stat = Data.define(:attrs)
    Sparkline = Data.define(:attr, :label, :height)
    Table = Data.define(:scope, :group_by, :sort, :limit)

    Panel = Data.define(:name, :resource, :span, :title, :items) do
      def table = items.find { |i| i.is_a?(Table) }
    end

    Row = Data.define(:height, :panels)

    # A screen made of rows of panels. Each panel shows one resource.
    class Dashboard
      attr_reader :name, :title, :rows

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
      end

      def panels = rows.flat_map(&:panels)

      class Builder
        def initialize(dashboard) = @d = dashboard

        def title(text) = @d.instance_variable_set(:@title, text)

        # `height:` in terminal lines; rows without one share the remaining space.
        def row(height: nil, &block)
          builder = RowBuilder.new
          builder.instance_eval(&block)
          @d.rows << Row.new(height:, panels: builder.panels)
        end
      end

      class RowBuilder
        attr_reader :panels

        def initialize = @panels = []

        # `span:` is a relative width; panels in a row split it by their spans.
        def panel(name, resource: name, span: 1, title: nil, &block)
          items = PanelBuilder.new.tap { |b| b.instance_eval(&block) if block }.items
          items = [Table.new(scope: nil, group_by: nil, sort: nil, limit: nil)] if items.empty?
          @panels << Panel.new(name:, resource:, span:, title:, items:)
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
      end
    end
  end
end
