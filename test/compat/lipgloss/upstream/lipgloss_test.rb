# frozen_string_literal: true

# Ported from lipgloss-ruby test/lipgloss_test.rb at tag v0.2.2 (MIT License, Copyright (c) 2025
# Marco Roth). Changes: requires upstream_helper (plain Minitest, r2ui drop-in) instead of test_helper,
# and lives in LipglossUpstream (see upstream_helper) instead of Lipgloss.
require_relative "upstream_helper"

module LipglossUpstream
  class LipglossTest < Spec
    it "has a version number" do
      refute_nil Lipgloss::VERSION
    end

    it "has position constants" do
      assert_equal 0.0, Lipgloss::TOP
      assert_equal 1.0, Lipgloss::BOTTOM
      assert_equal 0.0, Lipgloss::LEFT
      assert_equal 1.0, Lipgloss::RIGHT
      assert_equal 0.5, Lipgloss::CENTER
    end

    it "has border constants" do
      assert_equal :normal, Lipgloss::NORMAL_BORDER
      assert_equal :rounded, Lipgloss::ROUNDED_BORDER
      assert_equal :thick, Lipgloss::THICK_BORDER
      assert_equal :double, Lipgloss::DOUBLE_BORDER
      assert_equal :hidden, Lipgloss::HIDDEN_BORDER
      assert_equal :block, Lipgloss::BLOCK_BORDER
      assert_equal :ascii, Lipgloss::ASCII_BORDER
    end

    it "has no tab conversion constant" do
      assert_equal(-1, Lipgloss::NO_TAB_CONVERSION)
    end
  end
end
