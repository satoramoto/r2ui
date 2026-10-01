# frozen_string_literal: true

# s32-screen: a program that draws itself, like a plain Bubble Tea model's `view`.
#
#   R2UI.dashboard do
#     state count: 0                                   # s05
#     on_key("+") { state[:count] += 1 }               # s03
#     on_key("-") { state[:count] -= 1 }
#     screen do |width, height|
#       "count: #{state[:count]}\n\n+/- to change, q to quit (#{width}x#{height})"
#     end
#   end
#
# The block runs on a Context (state, helpers) every frame with the window size and returns the
# whole view as a String ("\n" between lines, ANSI styling such as a lipgloss render kept). No
# panels and no status bar are drawn, so the dashboard has no rows. Keys still go through the
# usual routing: `on_key` / `on` handlers first, then the core, so `q` and ctrl+c quit unless a
# binding takes `q`.
module R2UI
  module Ext
    module Screen
      Declaration = Data.define(:block)
    end
  end

  extension :screen do
    dsl :dashboard do
      def screen(&block)
        raise ArgumentError, "screen needs a block" unless block
        raise ArgumentError, "screen is already set for this dashboard" if @d.declared(:screen).any?

        declare(:screen, Ext::Screen::Declaration.new(block:))
      end
    end

    setup do
      if dashboard.declared(:screen).any? && dashboard.rows.any?
        raise Error, "dashboard #{dashboard.name}: screen draws the whole view, so it can't have rows"
      end
    end

    view_override do
      screen = dashboard.declared(:screen).first
      call(screen.block, width, height).to_s if screen
    end
  end
end
