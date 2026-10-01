#!/usr/bin/env ruby
# frozen_string_literal: true

# `heading` and `done` around a task list. Try:
#   ruby examples/cli/summary.rb install
#   ruby examples/cli/summary.rb install | cat
require_relative "../../lib/r2ui/cli"

R2UI.cli "pkg" do
  summary "A pretend package manager"

  command :install, "Install the packages" do
    run do
      heading "pkg v1.4.0"
      tasks do
        step("Resolving 42 packages") { sleep 0.3 }
        step("Fetching") { |s| (1..42).each { |i| s.detail = "#{i}/42"; sleep 0.01 } }
        step("Linking") { sleep 0.2 }
      end
      done "Added 42 packages"
    end
  end
end.start
