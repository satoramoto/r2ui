#!/usr/bin/env ruby
# frozen_string_literal: true

# Bullet and numbered lists (c16-list). Try:
#   ruby examples/cli/list.rb
#   ruby examples/cli/list.rb --numbered
#   COLUMNS=40 ruby examples/cli/list.rb | cat
require_relative "../../lib/r2ui/cli"

R2UI.cli "list" do
  summary "Print what a release contains"
  flag :numbered, short: "n", desc: "Number the items"

  run do
    say "Release 1.4.0", :heading
    list [
      "Faster boot: the dashboard DSL is only loaded when a command opens a dashboard",
      "New helpers",
      ["tasks and step, an npm-style task list", "confirm, a yes/no prompt"],
      "Fixes",
      ["Help is plain text in a pipe", "A closed stdout ends quietly with exit code 0"]
    ], numbered: options[:numbered]
  end
end.start
