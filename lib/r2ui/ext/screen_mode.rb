# frozen_string_literal: true

# s13-screen-mode: alt screen vs inline (Bubbletea's WithAltScreen, EnterAltScreen, ExitAltScreen).
#
#   R2UI.dashboard do
#     inline height: 10               # no alt screen; draw 10 lines under the prompt
#     row { panel(:log, resource: nil) { view { state[:last].to_s } } }
#   end
#
# A dashboard takes the whole terminal in the alt screen by default. `inline height: N` runs it in
# the normal screen instead, drawn N lines tall (at the terminal's width), so the last frame stays
# in the scrollback when the program quits.
#
# Any block can switch at runtime with the helpers, which enqueue Bubbletea's commands:
#
#   on_key "f" do enter_alt_screen end   # full screen (an inline dashboard then draws full height)
#   on_key "i" do exit_alt_screen end    # back to the normal screen
module R2UI
  module Ext
    module ScreenMode
      # What `inline` declares on the dashboard.
      Inline = Data.define(:height)

      module_function

      # The inline height the dashboard declared, or nil.
      def inline_height(dashboard) = dashboard.declared(:inline).last&.height
    end
  end

  extension :screen_mode do
    dsl :dashboard do
      def inline(height:)
        unless height.is_a?(Integer) && height.positive?
          raise ArgumentError, "inline needs a positive integer height, got #{height.inspect}"
        end

        declare(:inline, Ext::ScreenMode::Inline.new(height:))
      end
    end

    helpers do
      def enter_alt_screen
        store(:screen_mode)[:alt] = true
        command(Bubbletea.enter_alt_screen)
      end

      def exit_alt_screen
        store(:screen_mode)[:alt] = false
        command(Bubbletea.exit_alt_screen)
      end
    end

    program_options do
      Ext::ScreenMode.inline_height(dashboard) ? { alt_screen: false } : {}
    end

    frame_size do |width, height|
      inline = Ext::ScreenMode.inline_height(dashboard)
      inline && !store(:screen_mode)[:alt] ? [width, inline] : [width, height]
    end
  end
end
