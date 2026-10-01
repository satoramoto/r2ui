# frozen_string_literal: true

module R2UI
  # Converts between Bubbletea key messages and the key names r2ui's core uses:
  # typed text as a String ("q", "K", " ", or a whole paste), named keys as Symbols
  # (:up, :page_down, :enter, :escape, :interrupt, :back_tab, ...); keys the core has no name for
  # keep their Bubbletea name as a Symbol (:"ctrl+r", :f1, :delete, :"alt+x").
  module Keys
    # Bubbletea name => core name, where they differ.
    NAMES = {
      "pgup" => :page_up, "pgdown" => :page_down, "shift+tab" => :back_tab, "esc" => :escape,
      "ctrl+c" => :interrupt, "ctrl+h" => :backspace, "ctrl+j" => :enter, "space" => " "
    }.freeze
    # Core name => Bubbletea name, for building messages (App#press).
    BUBBLETEA = NAMES.reject { |k, _| %w[ctrl+h ctrl+j].include?(k) }.to_h { |k, v| [v, k] }.freeze

    module_function

    # The core name for a Bubbletea::KeyMessage.
    def name(message)
      return message.char if message.runes? && !message.alt

      key = message.to_s
      NAMES.fetch(key) { key.to_sym }
    end

    # A Bubbletea::KeyMessage for a core name (:up, "q", " ") or a Bubbletea name ("ctrl+r", "f1").
    def message(key)
      return key if key.is_a?(Bubbletea::KeyMessage)

      name = BUBBLETEA.fetch(key, key.to_s)
      alt = name.start_with?("alt+") && name.length > 4
      base = alt ? name.delete_prefix("alt+") : name
      type = key_type(base)
      return Bubbletea::KeyMessage.new(key_type: type, runes: base == "space" ? [32] : [], alt:) if type

      Bubbletea::KeyMessage.new(key_type: Bubbletea::KeyMessage::KEY_RUNES, runes: base.codepoints, alt:)
    end

    def key_type(name)
      @types ||= R2UI::Compat::Tea::Input::KEY_NAMES.to_h { |type, n| [n, type] }.except("runes")
      @types[name]
    end
  end
end
