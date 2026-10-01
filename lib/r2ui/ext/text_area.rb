# frozen_string_literal: true

# s21-text-area: a multi-line text box (bubbles' TextArea) in a panel.
#
#   R2UI.dashboard do
#     row height: 8 do
#       panel :notes, resource: nil do
#         text_area :notes, placeholder: "write here", height: 4   # height: optional, else the panel's
#       end
#     end
#     on_key "ctrl+s" do File.write("notes.md", area_value(:notes)) end
#   end
#
# The area takes the keys while its panel has focus: typing, enter for a new line, arrows and
# the usual editing keys (all bubbles' own behavior). esc hands keys back to the dashboard (the
# panel stays focused; tab away and back to type again). `area_value(:name)` reads the text from
# any block. The area is as wide as the panel and as tall as `height:` (at most the panel's
# space); without `height:` it fills the panel.
module R2UI
  module Ext
    module TextArea
      Item = Data.define(:name, :placeholder, :height)

      module_function

      # The focused panel's text area item, if its area has key focus (else nil).
      def focused(app)
        app.focus&.items&.each do |item|
          next unless item.is_a?(Item)

          model = app.component(item.name)
          return item if model&.focused?
        end
        nil
      end
    end
  end

  extension :text_area do
    dsl :panel do
      def text_area(name, placeholder: "", height: nil)
        raise ArgumentError, "text_area needs a positive height, got #{height}" if height && height.to_i < 1

        Component.require_bubbles!
        item(Ext::TextArea::Item.new(name:, placeholder: placeholder.to_s, height: height&.to_i))
      end
    end

    helpers do
      def area_value(name) = component(name)&.value
    end

    component(Ext::TextArea::Item, focusable: true) do |item|
      Bubbles::TextArea.new(height: item.height || Bubbles::TextArea::DEFAULT_HEIGHT).tap do |area|
        area.placeholder = item.placeholder
      end
    end

    # Sizes the area to the space it has, then lets bubbles draw it.
    panel_item(Ext::TextArea::Item) do |item|
      area = component(item.name)
      area.width = [width, 1].max
      area.height = [item.height || height, height].min.clamp(1..)
      area.view
    end

    on(->(msg) { msg.is_a?(Bubbletea::KeyMessage) && Keys.name(msg) == :escape }, priority: 50) do
      pass unless Ext::TextArea.focused(app)

      focus_component(nil)
    end
  end
end
