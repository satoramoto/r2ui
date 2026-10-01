# frozen_string_literal: true

# s17-resize: react to the window size, and refuse to draw below a minimum.
#
#   R2UI.dashboard do
#     on_resize { |width, height| state[:narrow] = width < 100 }
#     min_size 80, 20
#   end
#
# `on_resize` runs on every Bubbletea::WindowSizeMessage, the first one (sent at startup)
# included, on the update thread (a Context); a command it returns runs. It only observes the
# message, so the core still records the new size.
#
# Below `min_size` (width or height short) the whole view is a centered
# "terminal too small (WxH, need 80x20)" message instead of the dashboard.
module R2UI
  module Ext
    module Resize
      MinSize = Data.define(:width, :height)

      module_function

      # `height` lines with `text` centered in them (clipped to `width`).
      def too_small(width, height, min)
        text = "terminal too small (#{width}x#{height}, need #{min.width}x#{min.height})"[0, [width, 0].max]
        lines = Array.new([height, 1].max, "")
        lines[(lines.size - 1) / 2] = (" " * ((width - text.length) / 2)) + text
        lines.join("\n")
      end
    end
  end

  extension :resize do
    dsl :dashboard do
      def on_resize(&block)
        raise ArgumentError, "on_resize needs a block" unless block

        declare(:on_resize, block)
      end

      def min_size(width, height)
        unless width.is_a?(Integer) && height.is_a?(Integer) && width.positive? && height.positive?
          raise ArgumentError, "min_size needs positive integer width and height, got #{width}x#{height}"
        end

        declare(:min_size, Ext::Resize::MinSize.new(width:, height:))
      end
    end

    observe Bubbletea::WindowSizeMessage do |message|
      dashboard.declared(:on_resize).each { |block| call(block, message.width, message.height) }
    end

    view_override do
      min = dashboard.declared(:min_size).last
      next unless min && width && height
      next if width >= min.width && height >= min.height

      Ext::Resize.too_small(width, height, min)
    end
  end
end
