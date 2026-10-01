#!/usr/bin/env ruby
# frozen_string_literal: true

# An `npm outdated`-style listing with the c10 `table` helper. Try:
#   ruby examples/cli/table.rb outdated
#   ruby examples/cli/table.rb outdated | cat
#   ruby examples/cli/table.rb outdated | awk 'NR > 1 { print $1 }'
#   ruby examples/cli/table.rb services
require_relative "../../lib/r2ui/cli"

R2UI.cli "pkgs" do
  summary "Look at a project's packages"

  command :outdated, "List packages with newer versions" do
    run do
      table [
        ["rails", "7.1.0", "7.1.4", "8.0.1", "12 MB"],
        ["pg", "1.5.4", "1.5.9", "1.5.9", "1.2 MB"],
        ["puma", "6.4.0", "6.4.3", "6.5.0", "640 kB"],
        ["sidekiq", "7.2.0", "7.3.7", "8.0.0", "2.4 MB"]
      ], headers: %w[Package Current Wanted Latest Size], align: { "Size" => :right }
    end
  end

  command :services, "Show services (rows as Hashes)" do
    run do
      table [
        { name: "api", state: "running", replicas: 3, note: "healthy" },
        { name: "web", state: "running", replicas: 2 },
        { name: "worker", state: "stopped", replicas: 0, note: "paused for the migration window" }
      ], align: { replicas: :right }
    end
  end
end.start
