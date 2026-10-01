# frozen_string_literal: true

# Makes `require "bubbletea"` and `require "lipgloss"` load r2ui's pure-Ruby versions, so code
# written for the Charm Ruby gems (and pure-Ruby gems on top of them, like bubbles) runs unchanged:
#
#   require "r2ui/drop_in"
#   require "bubbles"   # now runs on r2ui
#
# Load it before anything requires the real gems.

loaded = $LOADED_FEATURES.grep(%r{/gems/(bubbletea|lipgloss)-[^/]+/})
unless loaded.empty?
  raise LoadError, "r2ui/drop_in must be required before the real bubbletea/lipgloss gems (already loaded: #{loaded.first})"
end

$LOAD_PATH.unshift(File.expand_path("compat/load_path", __dir__))
