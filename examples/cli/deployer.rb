#!/usr/bin/env ruby
# frozen_string_literal: true

# A pretend deploy tool showing the r2ui CLI DSL. Try:
#   ruby examples/cli/deployer.rb --help
#   ruby examples/cli/deployer.rb deploy api --env production
#   ruby examples/cli/deployer.rb deploy api --env production --force | cat
require_relative "../../lib/r2ui/cli"

R2UI.cli "deployer" do
  summary "Ship apps to the fleet"
  flag :verbose, short: "v", desc: "Show more detail"

  command :deploy, "Deploy an app" do
    aliases :d, :ship
    argument :app, desc: "App to deploy"
    argument :sha, default: "HEAD", desc: "Commit to deploy"
    option :env, short: "e", default: "staging", in: %w[staging production], desc: "Target environment"
    option :replicas, :integer, default: 3, desc: "Instances to run"
    flag :force, short: "f", desc: "Skip the production confirmation"

    run do
      app, env, replicas = args[:app], options[:env], options[:replicas]
      if env == "production" && !options[:force]
        confirm("Deploy #{app} to production?") or abort!("cancelled")
      end
      tasks do
        step("Building #{app}@#{args[:sha]}") { sleep 0.4 }
        step("Running migrations") { |s| s.skip!("none pending") }
        step("Uploading image") do |s|
          (1..5).each { |i| s.detail = "#{i * 20}%"; sleep 0.15 }
        end
        step("Starting #{replicas} replicas") do |s|
          (1..replicas).each { |i| s.detail = "#{i}/#{replicas}"; sleep 0.2 }
        end
      end
      say "Deployed #{app} to #{env} (#{replicas} replicas)", :success
      say "  logs: deployer status #{app}", :muted if options[:verbose]
    end
  end

  command :status, "Show what's running" do
    argument :app, default: "api"
    run { say "#{args[:app]}: 3/3 replicas healthy on staging" }
  end

  command :db, "Database tasks" do
    command(:migrate, "Run pending migrations") { run { step("Migrating") { sleep 0.3 } } }
    command(:rollback, "Undo the last migration") do
      option :steps, :integer, default: 1
      run { step("Rolling back #{options[:steps]}") { sleep 0.3 } }
    end
  end
end.start
