# frozen_string_literal: true

module R2UI
  # Hosts Bubbletea-style models (bubbles components, or your own: `update(msg)` → [model, cmd],
  # `view` → String) as panel items. An extension declares one with
  #
  #   component(SpinnerItem) { |item| Bubbles::Spinner.new }                # build block, runs on a Context
  #   component(InputItem, focusable: true) { |item| Bubbles::TextInput.new }
  #
  # and the app then, for every panel item of that class:
  # - builds the model once, in App#init, and runs its `init` (if it has one);
  # - sends it every non-key message (ticks, window size, mouse, your own messages) and batches the
  #   commands it returns;
  # - if `focusable`, sends it the key messages while its panel has focus (the first focusable item
  #   in the panel), except tab / shift+tab (panel focus) and ctrl+c (quit); calls its `focus`
  #   (or `focus!`) / `blur` as its panel gains and loses focus;
  # - draws `model.view` in the panel, unless the extension registers its own `panel_item` drawer.
  module Component
    # One hosted model. `item` is the DSL object the panel holds; `model` changes as update returns.
    Instance = Struct.new(:panel, :item, :spec, :model, :focused, keyword_init: true) do
      def name = item.respond_to?(:name) ? item.name : nil
      def focusable? = spec.options.fetch(:focusable, false)
    end

    Spec = Data.define(:matcher, :options, :build)

    # Keys a focused component never sees.
    RESERVED = %i[tab back_tab interrupt].freeze

    module_function

    # Bubbles is an optional dependency: component extensions call this when first used (not at
    # load time). It opts into r2ui/drop_in, so bubbles' `require "bubbletea"`/`"lipgloss"` load
    # r2ui's engine instead of the real gems.
    def require_bubbles!
      return if defined?(::Bubbles)

      begin
        require_relative "drop_in"
      rescue LoadError => e
        raise Error, "bubbles components run on r2ui's Bubbletea, but #{e.message}"
      end
      begin
        require "bubbles"
      rescue LoadError
        raise Error, "this needs the bubbles gem: add `gem \"bubbles\"` to your Gemfile"
      end
    end

    # [model, command] from an init/update result (a pair, a bare command, or nil).
    def split(model, result)
      return result if result.is_a?(Array) && result.size == 2 && !Context.command?(result.first)

      [model, Context.command?(result) ? result : nil]
    end

    def focus(instance)
      model = instance.model
      method = %i[focus focus!].find { |m| model.respond_to?(m) }
      method && model.public_send(method)
    end

    def blur(instance)
      instance.model.blur if instance.model.respond_to?(:blur)
    end
  end
end
