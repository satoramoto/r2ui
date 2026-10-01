#!/usr/bin/env ruby
# frozen_string_literal: true

# --color / --no-color. Try:
#   ruby examples/cli/color_option.rb build               # coloured, redrawn in place
#   ruby examples/cli/color_option.rb build --no-color    # redrawn in place, no colour
#   ruby examples/cli/color_option.rb build | cat         # plain lines
#   ruby examples/cli/color_option.rb build --color | cat # styled lines, no redraw
require_relative "../../lib/r2ui/cli"

R2UI.cli "painter" do
  summary "Shows what --color and --no-color change"
  color_option

  command :build, "Build something" do
    run do
      tasks do
        step("Resolving") { sleep 0.3 }
        step("Compiling") { |s| s.skip!("up to date") }
        step("Linking") { sleep 0.3 }
      end
      say "Built in #{shell.color? ? "colour" : "plain text"}", :success
    end
  end
end

R2UI::CLI.start
