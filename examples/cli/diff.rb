#!/usr/bin/env ruby
# frozen_string_literal: true

# Compare two files, or a built-in pair of configs, as a coloured unified diff. Try:
#   ruby examples/cli/diff.rb
#   ruby examples/cli/diff.rb --context 1
#   ruby examples/cli/diff.rb Gemfile Gemfile.lock | cat
# Exits 1 when the texts differ, like diff(1).
require_relative "../../lib/r2ui/cli"

DEPLOYED = <<~YAML
  app: api
  env: production
  replicas: 2
  region: eu
  timeout: 30
  health: /up
  log_level: info
YAML

LOCAL = <<~YAML
  app: api
  env: production
  replicas: 4
  region: eu
  timeout: 30
  health: /up
  log_level: debug
  tracing: true
YAML

R2UI.cli "confdiff" do
  summary "Show what changed between two files"
  argument :old, :path, required: false, desc: "Old file (default: a sample config)"
  argument :new, :path, required: false, desc: "New file"
  option :context, :integer, short: "U", default: 3, desc: "Unchanged lines around each change"

  run do
    old_text, new_text, labels =
      if args[:old] && args[:new]
        [File.read(args[:old]), File.read(args[:new]), [args[:old], args[:new]]]
      else
        [DEPLOYED, LOCAL, ["config.yml (deployed)", "config.yml (local)"]]
      end
    halt(1) if diff(old_text, new_text, labels:, context: options[:context])
    say "No differences", :muted
  end
end.start
