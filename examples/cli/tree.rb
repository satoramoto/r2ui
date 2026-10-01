#!/usr/bin/env ruby
# frozen_string_literal: true

# An `npm ls`-style dependency tree with the c08 `tree` helper. Try:
#   ruby examples/cli/tree.rb
#   ruby examples/cli/tree.rb --depth 1
#   ruby examples/cli/tree.rb | cat
require_relative "../../lib/r2ui/cli"

DEPENDENCIES = {
  "rails@7.1.3" => {
    "actionpack@7.1.3" => { "rack@3.0.9" => nil, "rack-test@2.1.0" => nil },
    "activerecord@7.1.3" => ["activemodel@7.1.3"],
    "activesupport@7.1.3" => %w[i18n@1.14.1 tzinfo@2.0.6 concurrent-ruby@1.2.3]
  },
  "pg@1.5.4" => nil,
  "@hotwired/turbo@8.0.4" => nil
}.freeze

R2UI.cli "deps" do
  summary "Show the dependency tree"
  option :depth, :integer, desc: "Levels to show below the app"

  run { tree("shop@1.0.0", DEPENDENCIES, depth: options[:depth]) }
end.start
