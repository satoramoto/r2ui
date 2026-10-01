#!/usr/bin/env ruby
# frozen_string_literal: true

# Styled log levels (c06-log). Try:
#   ruby examples/cli/log.rb install
#   ruby examples/cli/log.rb install -v          # with debug lines
#   ruby examples/cli/log.rb install 2>&1 | cat  # plain lines, no escape codes
require_relative "../../lib/r2ui/cli"

R2UI.cli "pkg" do
  summary "A pretend package manager"
  flag :verbose, short: "v", desc: "Show debug lines"

  command :install, "Install dependencies" do
    run do
      info "Using node 20.11.0"
      debug "lockfile: pnpm-lock.yaml (v9)"
      tasks do
        step("Resolving packages") { sleep 0.3; debug "resolved 42 packages from cache" }
        step("Fetching") { |s| (1..4).each { |i| s.detail = "#{i}/4"; sleep 0.15 } }
        step("Linking") { info "linked 42 packages" }
      end
      warn "3 deprecated packages\nrequest@2.88.2, uuid@3.4.0, glob@7.2.3"
      error "postinstall of esbuild@0.19.0 failed (ignored)"
      success "Installed 42 packages"
    end
  end
end.start
