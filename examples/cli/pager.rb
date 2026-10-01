#!/usr/bin/env ruby
# frozen_string_literal: true

# A pretend changelog viewer showing `pager`. Try:
#   ruby examples/cli/pager.rb log                 # in less (or $PAGER): taller than the screen
#   ruby examples/cli/pager.rb log --count 3       # fits: printed
#   ruby examples/cli/pager.rb log | grep 1.4      # piped: printed, plain
require_relative "../../lib/r2ui/cli"

R2UI.cli "changes" do
  summary "Read the changelog"

  command :log, "Show releases, newest first" do
    option :count, :integer, default: 60, desc: "Releases to show"

    run do
      text = options[:count].downto(1).map do |n|
        version = "1.#{n / 10}.#{n % 10}"
        "#{shell.paint(version, :heading)} #{shell.paint("2026-#{format("%02d", (n % 12) + 1)}-01", :muted)}\n" \
          "  #{shell.paint("•", :accent)} Faster deploys and #{n} small fixes"
      end
      pager(text.join("\n\n"))
    end
  end
end.start
