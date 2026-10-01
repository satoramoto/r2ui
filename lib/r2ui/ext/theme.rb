# frozen_string_literal: true

# s18-theme: lipgloss styling for the dashboard's own drawing and for your `view` blocks.
#
#   R2UI.dashboard do
#     theme do
#       title foreground: "#7D56F4", bold: true     # panel titles
#       focus foreground: "#04B575"                 # the focused panel's border
#       border foreground: "240"                    # other borders (ANSI 256 index)
#       selected reverse: true, foreground: "#FAFAFA", background: "#7D56F4"
#     end
#
#     row do
#       panel :hello, resource: nil do
#         view { style(foreground: "#FF5F87", italic: true).render("hello") }
#       end
#     end
#   end
#
# `theme` restyles the canvas styles (`:title`, `:header`, `:border`, `:focus`, `:selected`, `:ok`,
# `:warn`, `:alert`, `:accent`, `:muted`, `:dim`, ...; a new name adds a style). Each line is a style
# name and lipgloss options: `foreground:`, `background:` (any lipgloss colour: "#RRGGBB", "201",
# "5", `Lipgloss::AdaptiveColor`, ...), and `bold:`, `italic:`, `underline:`, `reverse:`, `faint:`,
# `strikethrough:`, `blink:`. The colours come out exactly as lipgloss renders them for the
# terminal's colour profile (truecolor, 256, 16 colours, or none). `theme` may be used more than
# once; later lines win.
#
# `style(**options)` (any block) returns a `Lipgloss::Style` with each option applied as the
# lipgloss method of that name (`style(bold: true, padding: [0, 1], width: 20)`), so a `view` block
# can `render` with it.
#
# Lipgloss loads on first use: r2ui's pure-Ruby one (through `r2ui/drop_in`), unless the app has
# already loaded a `Lipgloss`.
module R2UI
  module Ext
    module Theme
      # The options a canvas style can take: the ones lipgloss turns into SGR parameters.
      OPTIONS = %i[foreground background bold italic underline reverse faint strikethrough blink].freeze

      # The body of a `theme` block: every call is `style_name **options`. A BasicObject, so names
      # like `warn` or `select` reach method_missing instead of Kernel.
      class Builder < BasicObject
        def initialize = @styles = {}

        def method_missing(name, *args, **options)
          ::Kernel.raise ::ArgumentError, "theme: #{name} takes only keyword options" unless args.empty?
          ::Kernel.raise ::ArgumentError, "theme: #{name} needs lipgloss options" if options.empty?

          unknown = options.keys - OPTIONS
          unless unknown.empty?
            ::Kernel.raise ::ArgumentError, "theme: #{name} got #{unknown.join(", ")}; use #{OPTIONS.join(", ")}"
          end

          @styles[name] = Theme.style(**options)
        end

        def respond_to_missing?(*) = true

        def __styles = @styles
      end

      module_function

      # Makes `Lipgloss` available: r2ui's pure-Ruby lipgloss unless one is already loaded.
      def require_lipgloss!
        return if defined?(::Lipgloss::Style)

        require_relative "../drop_in"
        require "lipgloss"
      end

      # A Lipgloss::Style with each option applied as the lipgloss method of that name.
      def style(**options)
        require_lipgloss!
        options.reduce(::Lipgloss::Style.new) do |style, (name, value)|
          unless ::Lipgloss::Style.public_method_defined?(name) && name != :render
            raise ArgumentError, "style: lipgloss has no #{name} option"
          end

          style.public_send(name, *(value.is_a?(Array) ? value : [value]))
        end
      end

      PROBE_SGR = /\A\e\[([0-9;:]*)m/

      # The SGR parameters lipgloss uses for `style` (for the current colour profile); "0" (plain)
      # when it renders no styling.
      def sgr(style) = style.render("x")[PROBE_SGR, 1] || "0"
    end
  end

  extension :theme do
    dsl :dashboard do
      def theme(&block)
        raise ArgumentError, "theme needs a block" unless block

        builder = Ext::Theme::Builder.new
        builder.instance_eval(&block)
        declare(:theme, builder.__styles)
      end
    end

    helpers do
      def style(**options) = Ext::Theme.style(**options)
    end

    styles do
      themes = dashboard.declared(:theme)
      themes.reduce({}, :merge).transform_values { |style| Ext::Theme.sgr(style) } unless themes.empty?
    end
  end
end
