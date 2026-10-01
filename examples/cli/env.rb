#!/usr/bin/env ruby
# frozen_string_literal: true

# Options from environment variables (c26-env).
#
#   ruby examples/cli/env.rb --help
#   DEPLOY_TOKEN=s3cret DEPLOY_PORT=8080 ruby examples/cli/env.rb
#   DEPLOY_PORT=eighty ruby examples/cli/env.rb        # usage error naming DEPLOY_PORT
#   DEPLOY_TOKEN=s3cret ruby examples/cli/env.rb --token typed | cat

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "r2ui/cli"

R2UI.cli "deployer" do
  summary "Show where a deploy would go"
  option :token, required: true, env: "DEPLOY_TOKEN", desc: "API token"
  option :port, :integer, short: "p", default: 80, env: "DEPLOY_PORT", desc: "Port"
  option :env, short: "e", in: %w[staging production], default: "staging", env: %w[DEPLOY_ENV RACK_ENV],
               desc: "Target environment"
  option :tags, many: true, env: "DEPLOY_TAGS", desc: "Release tags"
  flag :force, env: "DEPLOY_FORCE", desc: "Skip the checks"

  run do
    say("token  #{given?(:token) ? "typed" : "from DEPLOY_TOKEN"}")
    say("port   #{options[:port]}")
    say("env    #{options[:env]}")
    say("tags   #{options[:tags].join(", ")}") if options[:tags].any?
    say("force  #{options[:force]}")
  end
end

R2UI::CLI.start
