# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "minitest", "~> 5.25"
gem "rake", "~> 13.0"

# For the component extensions' tests (lib/r2ui/ext/, docs/dsl.md). Apps that use components add
# bubbles themselves; it pulls in the real bubbletea/lipgloss gems, which r2ui shadows and never loads.
gem "bubbles", "0.1.1", require: false
# Pinned to the versions r2ui reproduces, so the bundle's copies match the spec.
gem "bubbletea", "0.1.4", require: false
gem "lipgloss", "0.2.2", require: false
gem "harmonica", "0.1.1", require: false

# For `rake bench` / `rake bench:profile` (bench/, docs/performance.md). Development only: r2ui itself
# has no runtime dependencies.
group :development do
  gem "memory_profiler", require: false
  gem "stackprof", require: false
  gem "vernier", require: false
end
