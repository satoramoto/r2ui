# frozen_string_literal: true

# c17-ask: try it on a terminal, then piped (`echo web | ruby examples/cli/ask.rb | cat`,
# `echo a | ruby examples/cli/ask.rb` for a rejected answer).
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
require "r2ui/cli"

R2UI.cli "create" do
  summary "Create a project"
  run do
    name = ask("Project name?", default: "app", validate: ->(v) { "use at least 2 characters" if v.size < 2 })
    say "Creating #{name}"
  end
end.start
