#!/usr/bin/env ruby
# frozen_string_literal: true

# A command that opens a dashboard (c25-dashboard).
#
#   ruby examples/cli/dashboard.rb watch           full screen until q, then back in the shell
#   ruby examples/cli/dashboard.rb watch | cat     one plain frame
#
# The dashboard file is found next to this script, wherever it's run from.

require_relative "../../lib/r2ui/cli"

R2UI.cli "jobs" do
  summary "Background jobs"

  command :watch do
    summary "Watch the jobs (q quits)"
    option :height, :integer, desc: "Rows of the frame when not on a terminal"

    run do
      dashboard file: "../dsl/async.rb", height: options[:height]
      say "Done watching", :success if shell.interactive?
    end
  end
end.start
