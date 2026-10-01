# frozen_string_literal: true

# s14-mouse: mouse reporting, clicks and the wheel.
#
#   R2UI.dashboard do
#     mouse :cell                       # or :all (motion without a button held too); default :cell
#     on_click do |msg, panel|          # a Bubbletea::MouseMessage, and the panel under it (or nil)
#       flash "clicked #{panel&.name} at #{msg.x},#{msg.y}"
#     end
#     row { panel :process }
#   end
#
# With `mouse`, the program turns on mouse reporting (Bubbletea's `mouse_cell_motion` or
# `mouse_all_motion`) and turns it off again on exit. A left click focuses the panel under the
# pointer and, on a table row, selects that row; the wheel moves the selection of the table under
# the pointer (or of the focused one). `on_click` blocks run on a Context for every button press
# (left, middle, right; not the wheel, releases or motion), after the click has focused and
# selected, so `focus` and `selected_rows` already show the clicked row; a returned command runs.
#
# Buttons are Bubbletea 0.1.4's numbers, which pass the terminal's SGR button through: a left
# click is 0, middle 1, right 2, wheel up 4 and wheel down 5.
module R2UI
  module Ext
    module Mouse
      MODES = { cell: :mouse_cell_motion, all: :mouse_all_motion }.freeze
      LEFT = 0
      WHEEL = { Bubbletea::MouseMessage::BUTTON_WHEEL_UP => -1, Bubbletea::MouseMessage::BUTTON_WHEEL_DOWN => 1 }.freeze

      module_function

      # The panel drawn at x, y in the last frame (nil if none).
      def panel_at(app, x, y)
        app.panel_rects.each do |panel, rect|
          return panel if x >= rect.x && x < rect.x + rect.width && y >= rect.y && y < rect.bottom
        end
        nil
      end

      # Selects the table row drawn at screen row y in `panel`, if there is one there.
      def select_row(app, panel, y)
        state = app.panel_state(panel)
        top = table_top(app, panel)
        return unless state && top

        index = state.offset + (y - top - 1) # the row under the table's header line
        lines = app.panel_lines(panel)
        state.move(index - state.selected, lines.size) if y > top && index < lines.size
      end

      # Moves the selection of a table panel by `delta` rows.
      def scroll(app, panel, delta)
        state = panel && app.panel_state(panel)
        state&.move(delta, app.panel_lines(panel).size)
      end

      # The screen row of the table's header in `panel`, laid out as the renderer does: inside the
      # border, below a feed error line and the items before the table.
      def table_top(app, panel)
        rect = app.panel_rects[panel]
        return unless rect

        inner = rect.width < 2 || rect.height < 2 ? rect : rect.inner
        y = inner.y
        y += 1 if panel.resource && app.feeds[panel.resource]&.error
        panel.items.each do |item|
          return y if item.is_a?(DSL::Table)

          y += item_height(app, panel, item, inner.width, inner.bottom - y)
          return if y >= inner.bottom
        end
        nil
      end

      def item_height(app, panel, item, width, room)
        lines = case item
                when DSL::Gauge then 1
                when DSL::Stat then item.attrs.size
                when DSL::Sparkline then item.height + 1
                else extension_lines(app, panel, item, width, room)
                end
        lines.clamp(0, room)
      end

      def extension_lines(app, panel, item, width, height)
        ctx = Context.new(app)
        ctx.panel = panel
        ctx.width = width
        ctx.height = height
        drawer = Extensions.hooks(:panel_item).find { |h| h.match?(item) }
        text = drawer ? ctx.call(drawer.block, item) : app.components.find { |c| c.item.equal?(item) }&.model&.view
        text.to_s.split("\n").size
      end
    end
  end

  extension :mouse do
    dsl :dashboard do
      def mouse(mode = :cell)
        unless Ext::Mouse::MODES.key?(mode)
          raise ArgumentError, "mouse takes #{Ext::Mouse::MODES.keys.map(&:inspect).join(" or ")}, got #{mode.inspect}"
        end

        declare(:mouse, mode)
      end

      def on_click(&block)
        raise ArgumentError, "on_click needs a block" unless block

        declare(:on_click, block)
      end
    end

    program_options do
      mode = dashboard.declared(:mouse).last
      mode ? { Ext::Mouse::MODES.fetch(mode) => true } : {}
    end

    on Bubbletea::MouseMessage do |msg|
      pass if dashboard.declared(:mouse).empty? || !msg.press?

      panel = Ext::Mouse.panel_at(app, msg.x, msg.y)
      if (delta = Ext::Mouse::WHEEL[msg.button])
        Ext::Mouse.scroll(app, panel && app.panel_state(panel) ? panel : focus, delta)
      else
        if msg.button == Ext::Mouse::LEFT && panel
          app.focus = panel
          Ext::Mouse.select_row(app, panel, msg.y)
        end
        dashboard.declared(:on_click).each { |block| call(block, msg, panel) }
      end
      nil # the handler's own value would be enqueued as a command (the blocks are Procs)
    end
  end
end
