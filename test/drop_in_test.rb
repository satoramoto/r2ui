# frozen_string_literal: true

require "test_helper"
require "open3"

# Runs in a subprocess: drop_in changes the load path for the whole process.
class DropInTest < Minitest::Test
  LIB = File.expand_path("../lib", __dir__)

  def ruby(code)
    Open3.capture2e(RbConfig.ruby, "-I#{LIB}", "-e", code)
  end

  def test_requires_resolve_to_r2ui
    out, status = ruby(<<~RUBY)
      require "r2ui/drop_in"
      require "bubbletea"
      require "lipgloss"
      puts $LOADED_FEATURES.grep(/compat/).size
    RUBY
    assert status.success?, out
    assert_operator out.to_i, :>=, 4
  end

  def test_refuses_after_real_gem
    out, status = ruby(<<~RUBY)
      $LOADED_FEATURES << "/x/gems/bubbletea-0.1.4/lib/bubbletea.rb"
      require "r2ui/drop_in"
    RUBY
    refute status.success?
    assert_match(/before the real/, out)
  end
end
