#!/usr/bin/env ruby
# frozen_string_literal: true

# The c22 `edit` helper. Try:
#   ruby examples/cli/editor.rb                      # opens $VISUAL / $EDITOR / vi
#   EDITOR="code --wait" ruby examples/cli/editor.rb
#   ruby examples/cli/editor.rb | cat                # off a terminal: "✖ edit needs a terminal ..."
require_relative "../../lib/r2ui/cli"

R2UI.cli "notes" do
  summary "Write release notes in your editor"

  run do
    notes = edit("# Release notes\n\n- ")
    lines = notes.lines.map(&:rstrip).reject { |line| line.empty? || line.start_with?("#") }
    say "#{lines.size} line#{"s" unless lines.size == 1} saved"
  end
end.start
