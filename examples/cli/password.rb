#!/usr/bin/env ruby
# frozen_string_literal: true

# Hidden input (c18-password). On a terminal:
#
#   ruby examples/cli/password.rb login
#   ruby examples/cli/password.rb rotate
#
# From a pipe: `printf 's3cret\n' | ruby examples/cli/password.rb login`.
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
require "r2ui/cli"

R2UI.cli "vault" do
  summary "Store a token"

  command :login, "Save an API token" do
    run do
      token = password("API token?")
      say "Saved a #{token.size}-character token", :success
    end
  end

  command :rotate, "Set a new passphrase" do
    run do
      password("New passphrase?", confirm: true)
      say "Passphrase changed", :success
    end
  end
end.start
