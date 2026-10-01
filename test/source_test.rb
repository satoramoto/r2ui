# frozen_string_literal: true

require "test_helper"

# v0.3: one shared source feeding several resources (R2UI.source + `source from:`).
class SharedSourceTest < Minitest::Test
  def setup
    R2UI.reset!
    @calls = calls = []
    R2UI.source(:sample, every: 2) do |previous|
      calls << previous
      { processes: [{ pid: 1 }, { pid: 2 }], memory: { used: 10 + calls.size } }
    end
    R2UI.resource(:process) do
      source(from: :sample) { |s| s[:processes] }
      key :pid
      column :pid, format: :id
    end
    R2UI.resource(:memory) do
      source(from: :sample) { |s| s[:memory] }
      column :used, format: :integer
    end
    R2UI.dashboard { row { panel :process; panel(:memory) { stat :used } } }
  end

  def test_many_resources_fetch_the_source_once
    app = R2UI::App.new(R2UI.registry)
    app.feeds.each_value(&:refresh!)

    assert_equal 1, @calls.size
    assert_equal [{ pid: 1 }, { pid: 2 }], app.feeds[:process].rows
    assert_equal [{ used: 11 }], app.feeds[:memory].rows
  end

  def test_feeds_follow_the_source_interval_unless_they_set_their_own
    app = R2UI::App.new(R2UI.registry)
    assert_in_delta 2.0, app.feeds[:process].interval
  end

  def test_the_cache_expires_and_the_block_gets_the_previous_value
    now = 0.0
    sources = R2UI::Sources.new(R2UI.registry, clock: -> { now })
    first = sources.value(:sample)
    now = 1.0
    assert_same first, sources.value(:sample), "younger than 3/4 of the interval: reused"
    now = 1.5
    sources.value(:sample)
    assert_equal [nil, first], @calls
    sources.expire(:sample)
    sources.value(:sample)
    assert_equal 3, @calls.size
  end

  def test_each_app_has_its_own_cache
    R2UI::App.new(R2UI.registry).feeds[:process].refresh!
    R2UI::App.new(R2UI.registry).feeds[:process].refresh!
    assert_equal 2, @calls.size
  end

  def test_errors_show_on_every_feed_and_are_cached
    R2UI.source(:sample, every: 2, replace: true) do
      @calls << :boom
      raise "probe down"
    end
    app = R2UI::App.new(R2UI.registry)
    app.feeds.each_value(&:refresh!)
    assert_equal "RuntimeError: probe down", app.feeds[:process].error
    assert_equal "RuntimeError: probe down", app.feeds[:memory].error
    assert_equal 1, @calls.size
  end

  def test_unknown_source_fails_when_the_app_starts
    R2UI.resource(:bad) { source(from: :nope) }
    R2UI.dashboard(:other) { row { panel :bad } }
    error = assert_raises(R2UI::Error) { R2UI::App.new(R2UI.registry, :other) }
    assert_match(/no source named nope/, error.message)
  end

  def test_fetch_without_an_app_explains
    error = assert_raises(R2UI::Error) { R2UI.registry.resource(:process).fetch }
    assert_match(/reads source sample/, error.message)
  end

  def test_redefining_a_source_from_elsewhere_raises
    assert_raises(R2UI::Error) { R2UI.source(:sample) { 1 } }
    assert_raises(ArgumentError) { R2UI.source(:x, every: 0) { 1 } }
  end
end
