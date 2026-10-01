# frozen_string_literal: true

# s03-keys: custom key bindings.
#
#   R2UI.dashboard do
#     on_key "r", help: "refresh" do        # typed text, as the core names it
#       state[:refreshed_at] = Time.now
#       flash "refreshed"                   # any Context helper; a returned command runs too
#     end
#     on_key "ctrl+r", :f1, "enter" do      # Bubbletea names ("ctrl+r", "f1", "pgup") or core
#       quit                                # names (:enter, :page_up), as String or Symbol
#     end
#   end
#
# The block runs on the update thread (a Context; `message` is the Bubbletea::KeyMessage). A
# binding beats the core's own key (binding "s" stops the sort key), but not the search (/) or
# confirm (y/n) prompts while they're open, nor a focused component. `help:` adds a status-bar
# hint. Binding the same key twice in one dashboard raises.
module R2UI
  module Ext
    # Not `Keys`: that would shadow R2UI::Keys for every other extension under R2UI::Ext.
    module KeyBindings
      # What `on_key` declares on the dashboard: `keys` are core key names (R2UI::Keys.name).
      Binding = Data.define(:keys, :label, :help, :block)

      module_function

      # The core name of a key given as a core or Bubbletea name ("r", "ctrl+r", :f1, "enter").
      def normalize(key) = R2UI::Keys.name(R2UI::Keys.message(key))
    end
  end

  extension :keys do
    dsl :dashboard do
      def on_key(*keys, help: nil, &block)
        raise ArgumentError, "on_key needs at least one key" if keys.empty?
        raise ArgumentError, "on_key needs a block" unless block

        names = keys.map { |key| Ext::KeyBindings.normalize(key) }
        taken = @d.declared(:on_key).flat_map(&:keys)
        names.each do |name|
          raise ArgumentError, "on_key: #{name.inspect} is already bound" if taken.include?(name)

          taken << name
        end

        label = keys.map(&:to_s).join("/")
        declare(:on_key, Ext::KeyBindings::Binding.new(keys: names, label:, help:, block:))
      end
    end

    hints do
      dashboard.declared(:on_key).filter_map { |b| [b.label, b.help.to_s] if b.help }
    end

    on Bubbletea::KeyMessage do |key|
      name = R2UI::Keys.name(key)
      binding = dashboard.declared(:on_key).find { |b| b.keys.include?(name) }
      pass unless binding

      call(binding.block)
    end
  end
end
