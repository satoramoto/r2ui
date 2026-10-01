#!/usr/bin/env ruby
# frozen_string_literal: true

# The `spin` helper: one spinner line per piece of work. Try:
#   ruby examples/cli/spinner.rb install
#   ruby examples/cli/spinner.rb install | cat
#   ruby examples/cli/spinner.rb install --fail
require_relative "../../lib/r2ui/cli"

PACKAGES = %w[react react-dom zod vite typescript].freeze

R2UI.cli "pkg" do
  summary "Pretend package manager"

  command :install, "Install the packages" do
    flag :fail, desc: "Make the registry fail"

    run do
      spin("Checking for updates", clear: true) { sleep 0.5 }
      spin("Resolving", done: ->(n) { "Resolved #{n} packages" }) { sleep 0.6; PACKAGES.size }
      spin("Installing", done: "Installed") do |s|
        PACKAGES.each_with_index do |pkg, i|
          s.text = "Installing #{pkg} (#{i + 1}/#{PACKAGES.size})"
          sleep 0.3
          raise "registry returned 503 for #{pkg}" if options[:fail] && i == 2
        end
      end
      say "Done", :success
    end
  end
end.start
