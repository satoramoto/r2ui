#!/usr/bin/env ruby
# frozen_string_literal: true

# c19-choose: pick one of a list.
#
#   ruby -Ilib examples/cli/choose.rb            # a pointer list on a terminal
#   echo 2 | ruby -Ilib examples/cli/choose.rb   # reads a label or number from a pipe
require "r2ui/cli"

R2UI.cli "launch" do
  summary "Pick a region and a plan"

  run do
    region = choose("Region?", %w[eu-west us-east us-west ap-south], default: "eu-west")
    plan = choose("Plan?", { "Hobby (free)" => :hobby, "Pro ($20/mo)" => :pro, "Team ($50/mo)" => :team }, default: :pro)
    say "Launching on #{plan} in #{region}", :success
  end
end.start
