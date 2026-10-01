# frozen_string_literal: true

# s24-viewport: a scrollable text pane (bubbles' Viewport) in a panel.
#
#   R2UI.dashboard do
#     state log: []
#     row do
#       panel :log, resource: nil do
#         viewport(:log, follow: true) { state[:log].join("\n") }
#       end
#     end
#   end
#
# `viewport(name) { text }` hosts a `Bubbles::Viewport` sized to the panel. The block runs on a
# Context every frame and returns the text ("\n" splits lines, ANSI kept); the scroll position is
# kept as the text changes. While the panel is focused, bubbles' viewport keys scroll it (up/down,
# pgup/pgdown, j/k, ctrl+u/ctrl+d, g/G, home/end); keys that don't move it go on to the rest of the
# app, so "q" still quits. The mouse wheel scrolls it too, by the viewport's `mouse_wheel_delta`
# lines, when mouse reporting is on (`mouse :cell`). With `follow: true` it sticks to the bottom
# as the text grows, until you scroll up; scrolling back to the bottom follows again.
#
# `component(:log)` in any block is the Bubbles::Viewport (set `style`, `horizontal_step`, ...).
module R2UI
  module Ext
    module Viewport
      Item = Data.define(:name, :follow, :block)

      module_function

      # The hosted viewport instance in the focused panel, or nil.
      def focused(ctx) = ctx.app.components.find { |c| c.item.is_a?(Item) && c.panel.equal?(ctx.focus) }

      # Yields the focused viewport's instance; false if there is none or it didn't move.
      def scroll(ctx)
        instance = focused(ctx)
        return false unless instance

        before = [instance.model.y_offset, instance.model.x_offset]
        yield instance
        before != [instance.model.y_offset, instance.model.x_offset]
      end
    end
  end

  extension :viewport do
    dsl :panel do
      def viewport(name, follow: false, &block)
        raise ArgumentError, "viewport needs a block" unless block

        Component.require_bubbles!
        item(Ext::Viewport::Item.new(name:, follow:, block:))
      end
    end

    component(Ext::Viewport::Item) { |_item| Bubbles::Viewport.new(width: 0, height: 0) }

    panel_item(Ext::Viewport::Item) do |item|
      viewport = app.components.find { |c| c.item.equal?(item) && c.panel.equal?(panel) }.model
      at_bottom = viewport.at_bottom?
      viewport.width = width
      viewport.height = height
      viewport.content = call(item.block).to_s
      if item.follow && at_bottom
        viewport.goto_bottom
      else
        viewport.y_offset = viewport.y_offset # the panel may have grown
      end
      viewport.view
    end

    # Keys go to the focused panel's viewport before ordinary bindings; those it ignores pass on.
    on Bubbletea::KeyMessage, priority: 50 do |message|
      moved = Ext::Viewport.scroll(self) do |instance|
        instance.model, = Component.split(instance.model, instance.model.update(message))
      end
      pass unless moved
    end

    # bubbles' Viewport leaves the wheel to its host (its mouse handler is empty): scroll it here.
    on Bubbletea::MouseMessage, priority: 50 do |message|
      up = message.button == Bubbletea::MouseMessage::BUTTON_WHEEL_UP
      down = message.button == Bubbletea::MouseMessage::BUTTON_WHEEL_DOWN
      moved = (up || down) && Ext::Viewport.scroll(self) do |instance|
        viewport = instance.model
        next unless viewport.mouse_wheel_enabled

        up ? viewport.scroll_up(viewport.mouse_wheel_delta) : viewport.scroll_down(viewport.mouse_wheel_delta)
      end
      pass unless moved
    end
  end
end
