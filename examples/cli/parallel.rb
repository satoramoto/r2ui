#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds a pretend monorepo with `parallel`, like `pnpm -r build`. Try:
#   ruby examples/cli/parallel.rb build
#   ruby examples/cli/parallel.rb build --max 2 --fail web
#   ruby examples/cli/parallel.rb build | cat
require_relative "../../lib/r2ui/cli"

PACKAGES = { "core" => 0.6, "api" => 1.4, "web" => 2.2, "docs" => 0.9, "cli" => 1.1, "worker" => 1.7 }.freeze

R2UI.cli "mono" do
  summary "Build every package in the workspace"

  command :build, "Build all packages" do
    option :max, :integer, default: 4, desc: "Packages built at once"
    option :fail, desc: "Make this package fail"

    run do
      results = parallel(max: options[:max]) do
        PACKAGES.each do |name, seconds|
          job(name) do |j|
            steps = 10
            steps.times do |i|
              sleep seconds / steps
              j.detail = "#{(i + 1) * 100 / steps}%"
              raise "Module not found: ./missing" if name == options[:fail] && i == 5
            end
            j.detail = nil
            "#{name}/dist"
          end
        end
      end
      say ""
      say "Built #{results.size} packages", :success
    end
  end
end.start
