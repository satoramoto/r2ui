# frozen_string_literal: true

require "test_helper"

# v0.3: configurable history length; series survive rows that disappear for a while.
class HistoryLengthTest < Minitest::Test
  def setup = R2UI.reset!

  def test_capacity_bounds_each_series
    history = R2UI::History.new(capacity: 3)
    5.times { |i| history.record(:a, :cpu, i) }
    assert_equal [2.0, 3.0, 4.0], history[:a, :cpu]
  end

  def test_a_row_that_disappears_keeps_its_series_for_capacity_samples
    history = R2UI::History.new(capacity: 3)
    history.record(:a, :cpu, 1)
    history.prune([:a])
    2.times { history.prune([]) }
    assert_equal [1.0], history[:a, :cpu], "gone for 2 samples: kept"
    history.prune([])
    assert_empty history[:a, :cpu], "gone for 3 samples: forgotten"
  end

  def test_a_row_that_comes_back_continues_its_line
    history = R2UI::History.new(capacity: 5)
    history.record(:a, :cpu, 1)
    history.prune([:a])
    history.prune([])
    history.record(:a, :cpu, 2)
    history.prune([:a])
    assert_equal [1.0, 2.0], history[:a, :cpu]
  end

  def test_refresh_history_sets_the_feed_capacity
    R2UI.resource(:proc) do
      source { [{ pid: 1, cpu: 1.0 }] }
      key :pid
      refresh every: 2, history: 900
      column :cpu, format: :percent, sparkline: true
    end
    resource = R2UI.registry.resource(:proc)
    assert_equal 900, resource.history_size
    assert_in_delta 2.0, resource.interval
    assert_equal 900, R2UI::Feed.new(resource).history.capacity
    assert_raises(ArgumentError) { R2UI.resource(:bad) { source { [] }; refresh history: 0 } }
  end

  def test_default_history_is_still_120
    R2UI.resource(:proc) { source { [] } }
    assert_equal 120, R2UI.registry.resource(:proc).history_size
    assert_in_delta 1.0, R2UI.registry.resource(:proc).interval
  end

  def test_column_series_reads_an_attribute_or_a_lambda
    by_attr = R2UI::DSL::Column.build(:pressure, sparkline: :trend)
    by_proc = R2UI::DSL::Column.build(:pressure, sparkline: ->(row) { row[:trend].map { |v| v * 2 } })
    row = { pressure: 5, trend: [1, 2] }
    assert_equal [1.0, 2.0], by_attr.series(row)
    assert_equal [2.0, 4.0], by_proc.series(row)
    refute by_attr.history_sparkline?
    assert R2UI::DSL::Column.build(:cpu, sparkline: true).history_sparkline?
  end

  def test_history_sum_aligns_at_the_newest_value
    assert_equal [1.0, 3.0, 5.0], R2UI::History.sum([[1.0, 2.0, 3.0], [1.0, 2.0]])
  end
end
