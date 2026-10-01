# frozen_string_literal: true

# s15-paste: bracketed paste (Bubbletea's `WithBracketedPaste`).
#
#   R2UI.dashboard do
#     paste                                  # turn bracketed paste on
#     on_paste { |text| state[:clip] = text } # optional; on_paste alone turns it on too
#   end
#
# With bracketed paste on, the terminal sends a paste as one message instead of one key per
# character, so pasted text never runs key bindings ("q" in a paste does not quit). A paste goes to:
#
# 1. the search prompt (`/`), if it is open: appended to the search, with newlines and other control
#    characters dropped, so a paste never submits or cancels the prompt;
# 2. the focused component (a text input, say), as one KeyMessage carrying the whole text;
# 3. otherwise every `on_paste { |text| }` block, on a Context (it may flash, quit, return a
#    command). With no `on_paste`, the paste is dropped.
#
# Bracketed paste is turned off again on every exit path (the runner restores the terminal).
module R2UI
  module Ext
    module Paste
      # What the search prompt held before a paste, to clean what the core appended.
      Pending = Data.define(:panel, :search, :text)

      module_function

      # The engine decodes a paste as a runes KeyMessage named "[text]"; a typed key's name is its
      # own text, so a typed "[" is not a paste.
      def paste?(message)
        message.is_a?(Bubbletea::KeyMessage) && message.runes? && !message.alt &&
          !message.char.nil? && message.name == "[#{message.char}]"
      end

      MATCHER = ->(message) { paste?(message) }

      def enabled?(dashboard) = dashboard.declared(:paste).any? || dashboard.declared(:on_paste).any?

      def clean(text) = text.gsub(/[[:cntrl:]]/, "")
    end
  end

  extension :paste do
    dsl :dashboard do
      def paste = declare(:paste, true)

      def on_paste(&block)
        raise ArgumentError, "on_paste needs a block" unless block

        declare(:on_paste, block)
      end
    end

    program_options do
      { bracketed_paste: true } if Ext::Paste.enabled?(dashboard)
    end

    # The core search prompt takes keys before any handler and appends a pasted String as is.
    # Remember the search so after_update can drop the control characters it appended.
    observe Ext::Paste::MATCHER do |message|
      next unless Ext::Paste.enabled?(dashboard)

      search = app.panel_state(focus)&.search
      store(:paste)[:pending] = Ext::Paste::Pending.new(panel: focus, search:, text: message.char) if search
    end

    after_update do
      pending = store(:paste).delete(:pending)
      next unless pending

      panel_state = app.panel_state(pending.panel)
      if panel_state.search == pending.search + pending.text
        panel_state.search = pending.search + Ext::Paste.clean(pending.text)
      end
    end

    # Runs after the focused component (priority 50) and before ordinary bindings (0), so a paste
    # never reaches a key binding or the core keys.
    on Ext::Paste::MATCHER, priority: App::COMPONENT_PRIORITY - 1 do |message|
      pass unless Ext::Paste.enabled?(dashboard)

      dashboard.declared(:on_paste).each { |block| call(block, message.char) }
      nil # the blocks' commands are enqueued; returning the Array of blocks would enqueue them too
    end
  end
end
