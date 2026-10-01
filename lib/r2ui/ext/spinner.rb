# frozen_string_literal: true

# s25-spinner: bubbles' Spinner as a panel item.
#
#   R2UI.dashboard do
#     row height: 3 do
#       panel :work, resource: nil do
#         spinner :busy, style: :dot, label: "deploying", while: -> { state[:busy] }
#       end
#     end
#   end
#
# `style` names any of bubbles' spinners (`Bubbles::Spinners::DOT` is `:dot`, `MINI_DOT` is
# `:mini_dot`, ...). The spinner starts ticking at init on its own TickMessages (bubbles scopes them
# by id, so two spinners animate independently). With `while:` the item draws only while the lambda
# (run on a Context) is true; it keeps ticking meanwhile, so it resumes in step.
module R2UI
  module Ext
    module Spinner
      Item = Data.define(:name, :style, :label, :visible)

      module_function

      # The Bubbles::Spinners entry for `style` (a Symbol or String such as :dot or :mini_dot).
      def frames_for(style)
        Component.require_bubbles!
        const = style.to_s.upcase
        spec = Bubbles::Spinners.const_get(const, false) if Bubbles::Spinners.const_defined?(const, false)
        return spec if spec.is_a?(Hash) && spec[:frames]

        known = Bubbles::Spinners.constants.select { |c| Bubbles::Spinners.const_get(c).is_a?(Hash) }
        raise ArgumentError, "unknown spinner style #{style.inspect} (one of #{known.map { |c| c.to_s.downcase }.join(", ")})"
      end
    end
  end

  extension :spinner do
    dsl :panel do
      def spinner(name, style: :dot, label: nil, while: nil)
        visible = binding.local_variable_get(:while)
        raise ArgumentError, "spinner while: needs a callable" if visible && !visible.respond_to?(:call)

        Ext::Spinner.frames_for(style)
        item(Ext::Spinner::Item.new(name:, style:, label:, visible:))
      end
    end

    component(Ext::Spinner::Item) { |item| Bubbles::Spinner.new(spinner: Ext::Spinner.frames_for(item.style)) }

    panel_item(Ext::Spinner::Item) do |item|
      next "" if item.visible && !call(item.visible)

      model = app.components.find { |c| c.item.equal?(item) }&.model
      next "" unless model

      [model.view, item.label].compact.join(" ")
    end
  end
end
