#!/usr/bin/env ruby
# frozen_string_literal: true

# Pick a git branch by typing part of its name (c21-filter). Try:
#   ruby examples/cli/filter.rb                 # type to narrow, ↑/↓, enter
#   echo bill | ruby examples/cli/filter.rb     # the best match for "bill", no prompt
require_relative "../../lib/r2ui/cli"

BRANCHES = %w[
  main develop feature/billing feature/login feature/onboarding-emails fix/env-vars
  fix/flaky-specs release/1.4 release/1.5 chore/bump-rails spike/graphql docs/readme
].freeze

R2UI.cli "checkout" do
  summary "Switch to a branch"

  run do
    branch = filter("Branch?", BRANCHES)
    say "Switched to #{branch}", :success
  end
end.start
