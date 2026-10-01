# frozen_string_literal: true

module R2UI
  # Lays out a dashboard and draws every panel into a canvas.
  class Renderer
    HINTS = "tab panel  [ ] scope  g group  s/S sort  / search  ⏎ fold  z zoom  q quit"

    # The lines each table panel showed in the last frame, for selection and actions.
    attr_reader :lines

    def initialize(registry, feeds, states)
      @registry = registry
      @feeds = feeds
      @states = states
      @lines = {}
    end

    def render(dashboard, width:, height:, focus:, zoomed: false, prompt: nil)
      canvas = Canvas.new(width, height)
      body = Rect.new(x: 0, y: 0, width:, height: height - 1)
      if zoomed
        draw_panel(canvas, body, focus, true)
      else
        rows_layout(dashboard, body).each do |rect, panel|
          draw_panel(canvas, rect, panel, panel == focus)
        end
      end
      draw_status(canvas, height - 1, width, focus, prompt)
      canvas
    end

    private

    def rows_layout(dashboard, body)
      fixed = dashboard.rows.sum { |r| r.height || 0 }
      flexible = dashboard.rows.count { |r| r.height.nil? }
      share = flexible.zero? ? 0 : (body.height - fixed) / flexible
      y = body.y
      dashboard.rows.each_with_index.flat_map do |row, i|
        last = i == dashboard.rows.size - 1
        h = last ? body.bottom - y : (row.height || share)
        rect = Rect.new(x: body.x, y:, width: body.width, height: [h, 0].max)
        y += rect.height
        split(rect, row.panels)
      end
    end

    def split(rect, panels)
      total = panels.sum(&:span)
      x = rect.x
      panels.each_with_index.map do |panel, i|
        w = i == panels.size - 1 ? rect.x + rect.width - x : (rect.width * panel.span / total)
        r = rect.with(x:, width: w)
        x += w
        [r, panel]
      end
    end

    def draw_panel(canvas, rect, panel, focused)
      resource = @registry.resource(panel.resource)
      feed = @feeds.fetch(resource.name)
      state = @states[panel]
      title = panel.title || (panel.name == resource.name ? resource.title : panel.name.to_s.tr("_", " ").capitalize)
      inner = Widgets::Box.draw(canvas, rect, title:, focused:, tabs: state ? state.scope_tabs : [])
      return if inner.empty?

      if (error = feed.error)
        canvas.write(inner.x, inner.y, error, :alert, max: inner.width)
        inner = inner.take(1).last
      end

      rows = feed.rows
      record = rows.first
      panel.items.each do |item|
        break if inner.empty?

        inner = case item
                when DSL::Gauge then draw_gauge(canvas, inner, resource, record, item)
                when DSL::Stat then draw_stats(canvas, inner, resource, record, item)
                when DSL::Sparkline then draw_sparkline(canvas, inner, resource, feed, item)
                when DSL::Table then draw_table(canvas, inner, resource, feed, rows, panel, state, focused, item)
                end
      end
    end

    def draw_gauge(canvas, rect, resource, record, item)
      line, rest = rect.take(1)
      return rest unless record

      column = column_for(resource, item.attr)
      Widgets::Gauge.draw(canvas, line, label: item.label || column.label, value: column.read(record),
                                        total: column_for(resource, item.of).read(record), column:)
      rest
    end

    def draw_stats(canvas, rect, resource, record, item)
      area, rest = rect.take(item.attrs.size)
      return rest unless record

      Widgets::Stat.draw(canvas, area, item.attrs.map { |a| column_for(resource, a).then { |c| [c, c.read(record)] } })
      rest
    end

    def draw_sparkline(canvas, rect, resource, feed, item)
      area, rest = rect.take(item.height + 1)
      column = column_for(resource, item.attr)
      values = feed.history[Feed::SINGLE, column.key]
      label, chart = area.take(1)
      canvas.write(label.x, label.y, item.label || column.label, :muted)
      now = column.render(values.last)
      canvas.write(label.x + label.width - now.length, label.y, now, :bold)
      Widgets::Sparkline.draw(canvas, chart, values, max: column.format == :percent ? 100 : nil, style: :accent)
      rest
    end

    def draw_table(canvas, rect, resource, feed, rows, panel, state, focused, item)
      lines = Query.new(resource, rows, scope: state.scope, grouping: state.grouping, search: state.search,
                                        sort: state.sort, collapsed: state.collapsed).lines
      lines = lines.first(item.limit) if item.limit
      @lines[panel] = lines
      label_key = state.grouping && !state.grouping.tree? && resource.column(state.grouping.by) ? state.grouping.by : nil
      spark = ->(line, col) { feed.history.sum(line.rows.map { |r| feed.series_id(r) }, col.key) }
      Widgets::Table.new(resource, lines, state:, focused:, label_key:, spark:).draw(canvas, rect)
      rect.with(height: 0)
    end

    def draw_status(canvas, y, width, focus, prompt)
      left = prompt || @states[focus]&.status.to_s
      canvas.fill(Rect.new(x: 0, y:, width:, height: 1), " ", :reverse)
      canvas.write(1, y, left, :reverse, max: width - 2)
      hints = HINTS
      canvas.write(width - hints.length - 1, y, hints, :reverse) if left.length + hints.length + 4 <= width
    end

    def column_for(resource, key)
      resource.column(key) || DSL::Column.build(key)
    end
  end
end
