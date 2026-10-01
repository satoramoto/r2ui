#!/usr/bin/env ruby
# frozen_string_literal: true

# Boxed notices (c07-box). Try:
#   ruby examples/cli/box.rb
#   ruby examples/cli/box.rb | cat
require_relative "../../lib/r2ui/cli"
include R2UI::CLI::Helpers # rubocop:disable Style/MixinUsage -- a script

box "Created my-app\n\n  cd my-app\n  bin/dev", title: "Next steps"
box "Update available 1.3.0 → 1.4.0\nRun gem update deployer to update", title: "deployer", style: :warn
box "Deployed api to production in 4.2s", style: :success, padding: [0, 1]
box "日本語のテキストも右端が揃います", title: "幅", style: :accent
