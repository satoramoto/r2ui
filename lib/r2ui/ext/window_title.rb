# frozen_string_literal: true

# s12-window-title: the terminal window title (Bubbletea's SetWindowTitle, OSC 2).
#
#   R2UI.dashboard do
#     window_title "Agents"                              # set once, when the app starts
#     window_title { "#{state[:count]} deploys" }        # or: set at start, and again when it changes
#   end
#
#   on_key "r" do set_window_title("refreshing") end     # any block: set it now
#
# The block form runs on a Context after init and after every update; the title is sent only when
# its value differs from the last one sent, so an idle app writes nothing. A dashboard has one
# `window_title`. `set_window_title(text)` sends a title right away (it returns the command).
module R2UI
  module Ext
    module WindowTitle
      # What `window_title` declares on the dashboard: fixed text or a block.
      Title = Data.define(:text, :block) do
        def value(context) = (block ? context.call(block) : text).to_s
      end
    end
  end

  extension :window_title do
    dsl :dashboard do
      def window_title(text = nil, &block)
        raise ArgumentError, "window_title needs text or a block" if text.nil? == block.nil?
        raise ArgumentError, "window_title is already set" if @d.declared(:window_title).any?

        declare(:window_title, Ext::WindowTitle::Title.new(text:, block:))
      end
    end

    helpers do
      def set_window_title(text) = command(Bubbletea.set_window_title(text.to_s)) # rubocop:disable Naming/AccessorMethodName
    end

    after_update do
      title = dashboard.declared(:window_title).first
      next unless title

      sent = store(:window_title)
      value = title.value(self)
      next if sent.key?(:last) && sent[:last] == value

      sent[:last] = value
      set_window_title(value)
    end
  end
end
