# frozen_string_literal: true

# Test-only shim: `require "bubbletea"` loads r2ui's pure-Ruby Bubbletea while `require "lipgloss"`
# still finds the real gem (r2ui/drop_in would redirect both).
require_relative "../../../../../lib/r2ui/compat/bubbletea"
