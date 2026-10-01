#!/usr/bin/env ruby
# frozen_string_literal: true

# Shell completion for a tool (c24-completion). Try:
#   ruby examples/cli/completion.rb completion --help
#   ruby examples/cli/completion.rb completion zsh
#
# To use it, put the tool on your PATH as `shipit` (e.g. a symlink), then:
#   eval "$(shipit completion zsh)"        # or bash; fish: shipit completion fish | source
#   shipit d<TAB>  shipit deploy -e <TAB>  shipit db <TAB>
require_relative "../../lib/r2ui/cli"

R2UI.cli "shipit" do
  summary "Ship apps to the fleet"
  completion
  flag :verbose, short: "v", desc: "Show more detail"

  command :deploy, "Deploy an app" do
    aliases :d
    argument :app, desc: "App to deploy"
    option :env, short: "e", default: "staging", in: %w[staging production], desc: "Target environment"
    option :manifest, :path, desc: "Manifest file"
    flag :force, short: "f", desc: "Skip the checks"
    run { say "Deployed #{args[:app]} to #{options[:env]}", :success }
  end

  command :db, "Database tasks" do
    command(:migrate, "Run pending migrations") { run { say "Migrated", :success } }
    command(:rollback, "Undo the last migration") do
      option :steps, :integer, in: [1, 2, 3], default: 1, desc: "How many"
      run { say "Rolled back #{options[:steps]}", :success }
    end
  end
end.start
