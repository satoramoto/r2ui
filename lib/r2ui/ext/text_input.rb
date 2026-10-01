# frozen_string_literal: true

# s20-text-input: a one-line text field (bubbles' TextInput) in a panel.
#
#   R2UI.dashboard do
#     row height: 3 do
#       panel :search, resource: nil do
#         text_input :query, placeholder: "filter…", prompt: "> ", width: 30, char_limit: 64,
#                            on_submit: ->(value) { state[:q] = value }
#       end
#     end
#   end
#
# While its panel has focus, typed keys go to the input (tab / shift+tab still move panel focus,
# ctrl+c still quits). enter calls `on_submit` with the value (on a Context, so `state`, `flash`
# and returned commands work); esc blurs it, handing keys back to the core and your bindings while
# the panel stays focused; enter on its panel focuses it again. `input_value(:query)` reads the
# value from any block. Options left out keep bubbles' defaults; the field is drawn by bubbles.
module R2UI
  module Ext
    module TextInput
      Item = Data.define(:name, :options, :on_submit)

      # Bubbles::TextInput setters the keyword takes.
      OPTIONS = %i[placeholder prompt width char_limit].freeze

      module_function

      def build(item)
        Component.require_bubbles!
        model = Bubbles::TextInput.new
        item.options.each { |key, value| model.public_send(:"#{key}=", value) }
        model
      end

      def enter?(msg) = msg.is_a?(Bubbletea::KeyMessage) && Keys.name(msg) == :enter
      def escape?(msg) = msg.is_a?(Bubbletea::KeyMessage) && Keys.name(msg) == :escape

      # The text-input instances in the focused panel.
      def in_focus(app) = app.components.select { |c| c.panel == app.focus && c.item.is_a?(Item) }
    end
  end

  extension :text_input do
    dsl :panel do
      def text_input(name, on_submit: nil, **options)
        raise ArgumentError, "text_input needs a name" unless name

        unknown = options.keys - Ext::TextInput::OPTIONS
        raise ArgumentError, "text_input: unknown option #{unknown.join(", ")}" if unknown.any?

        Component.require_bubbles!
        item(Ext::TextInput::Item.new(name: name.to_sym, options: options.compact, on_submit:))
      end
    end

    helpers do
      def input_value(name) = component(name.to_sym)&.value
    end

    component(Ext::TextInput::Item, focusable: true) { |item| Ext::TextInput.build(item) }

    # The focused input handles enter and esc itself (before ordinary bindings).
    on(->(m) { Ext::TextInput.enter?(m) || Ext::TextInput.escape?(m) }, priority: 50) do |msg|
      input = Ext::TextInput.in_focus(app).find(&:focused)
      pass unless input

      if Ext::TextInput.escape?(msg)
        focus_component(nil)
      elsif input.item.on_submit
        call(input.item.on_submit, input.model.value)
      end
    end

    # enter on the panel of a blurred input focuses it again.
    on(->(m) { Ext::TextInput.enter?(m) }) do
      input = Ext::TextInput.in_focus(app).first
      pass unless input

      focus_component(input.name)
    end
  end
end
