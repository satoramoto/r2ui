#!/usr/bin/env ruby
# frozen_string_literal: true

# Pick several features with c20's choose_many. Try:
#   ruby examples/cli/choose_many.rb               # checkbox list on a terminal
#   echo "web app, 3" | ruby examples/cli/choose_many.rb   # one line from a pipe
require_relative "../../lib/r2ui/cli"
include R2UI::CLI::Helpers

features = choose_many("Features?", {
                         "API server" => :api, "Web app" => :web, "Background worker" => :worker,
                         "Postgres" => :postgres, "Redis cache" => :redis
                       }, selected: %i[api], min: 1)
say "Scaffolding #{features.join(", ")}"
