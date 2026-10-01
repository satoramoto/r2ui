# frozen_string_literal: true

# s02-view: a panel item drawn by a block, like a Bubbletea model's `view`.
#
#   R2UI.dashboard do
#     row height: 3 do
#       panel :clock, resource: nil do
#         view { "#{state[:ticks].to_i} ticks · #{width}x#{height}" }
#       end
#     end
#   end
#
# The block runs on a Context (state, width, height, panel, helpers) on every frame and returns a
# String; "\n" splits lines and ANSI styling (a lipgloss render) is kept. The panel gives it as
# many lines as it returns, up to the space left.
#
# The reference for panel items: a component story copies this shape (a `dsl :panel` keyword that
# adds an `item`, plus a `panel_item` drawer or a `component`).
module R2UI
  module Ext
    module View
      Item = Data.define(:block)
    end
  end

  extension :view do
    dsl :panel do
      def view(&block)
        raise ArgumentError, "view needs a block" unless block

        item(Ext::View::Item.new(block:))
      end
    end

    panel_item(Ext::View::Item) { |item| call(item.block).to_s }
  end
end
