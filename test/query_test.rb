# frozen_string_literal: true

require "test_helper"

class QueryTest < Minitest::Test
  def setup
    R2UI.reset!
    @resource = Fixtures.define_processes
    @rows = Fixtures::ROWS
  end

  def query(**) = R2UI::Query.new(@resource, @rows, **).lines

  def test_scope_and_default_sort
    lines = query(scope: @resource.default_scope)
    assert_equal [12, 10, 20, 21, 11], lines.map(&:id)
  end

  def test_free_text_search_matches_filter_attributes
    assert_equal [20, 21], query(search: "src/b").map(&:id).sort
  end

  def test_comparison_search_parses_by_format
    assert_equal [12, 10], query(search: "rss>300M").map(&:id)
    assert_equal [12], query(search: "cpu>=100").map(&:id)
    assert_equal [10], query(search: "name=claude").map(&:id)
  end

  def test_group_by_sums_numeric_columns
    lines = query(grouping: @resource.groupings[1])
    a = lines.find { |l| l.label == "/src/a" }

    assert_equal 3, a.count
    assert_in_delta 321.0, a.values[:cpu]
    assert_equal 3, a.values[:pid]
    assert_nil a.values[:name], "names differ, so no single value"
    assert_equal "/src/a", lines.first.label, "sorted by summed CPU"
  end

  def test_tree_rolls_up_subtrees
    lines = query(grouping: @resource.groupings.last, sort: [:pid, :asc])

    assert_equal [1, 10, 11, 12, 20, 21], lines.map(&:id)
    assert_equal [0, 1, 2, 3, 1, 2], lines.map(&:depth)
    claude = lines.find { |l| l.id == 10 }
    assert_in_delta 321.0, claude.values[:cpu]
    assert_equal 10, claude.values[:pid], "own value for non-summed columns"
    assert_equal 3, claude.count
  end

  def test_collapsed_nodes_hide_children
    lines = query(grouping: @resource.groupings.last, sort: [:pid, :asc], collapsed: Set[10])
    assert_equal [1, 10, 20, 21], lines.map(&:id)
    assert lines[1].collapsed
  end

  def test_tree_inside_scope_makes_orphans_roots
    lines = query(scope: @resource.default_scope, grouping: @resource.groupings.last, sort: [:pid, :asc])
    assert_equal [10, 11, 12, 20, 21], lines.map(&:id)
    assert_equal [0, 1, 2, 0, 1], lines.map(&:depth)
  end
end
