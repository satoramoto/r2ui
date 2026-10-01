# frozen_string_literal: true

# Helper for the upstream lipgloss-ruby test suite (https://github.com/marcoroth/lipgloss-ruby,
# test/test_helper.rb at tag v0.2.2, MIT License, Copyright (c) 2025 Marco Roth), ported to run
# against r2ui's pure-Ruby lipgloss drop-in.
#
# Adaptations from upstream:
# - plain Minitest instead of maxitest (the suite only uses Minitest::Spec `it`/`describe`);
# - `require "r2ui/drop_in"` first, so `require "lipgloss"` loads lib/r2ui/compat/lipgloss.
#
# Re-validating the port against the real gem: set LIPGLOSS_REAL=1 to skip the drop-in and load
# the installed lipgloss 0.2.2 gem instead. Run with plain ruby (the Gemfile has no lipgloss):
#
#   LIPGLOSS_REAL=1 ruby -Itest test/compat/lipgloss/upstream/style_test.rb

$LOAD_PATH.unshift File.expand_path("../../../../lib", __dir__)

if ENV["LIPGLOSS_REAL"] == "1"
  gem "lipgloss", "0.2.2"
else
  require "r2ui/drop_in"
end

require "lipgloss"
require "minitest/autorun"

def strip_ansi(string)
  string.gsub(/\e\[[0-9;]*[A-Za-z]/, "")
end

# Upstream defines its test classes inside `module Lipgloss`. Here they live in LipglossUpstream so
# they don't add constants to Lipgloss (a conformance case pins `Lipgloss.constants`, and every test
# runs in one process). Spec includes Lipgloss so bare constants (Style, Table, ...) resolve as
# they do upstream.
module LipglossUpstream
  class Spec < Minitest::Spec
    include Lipgloss
  end
end
