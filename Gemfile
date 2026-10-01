# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "minitest", "~> 5.25"
gem "rake", "~> 13.0"

# For the component extensions' tests (lib/r2ui/ext/, docs/dsl.md). Apps that use components add
# bubbles themselves; it pulls in the real bubbletea/lipgloss gems, which r2ui shadows and never loads.
gem "bubbles", "0.1.1", require: false
