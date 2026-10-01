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

  Job = Data.define(:id, :parent, :kind, :started, :size)
  T0 = Time.at(1_000_000)
  JOBS = [
    Job.new(id: 1, parent: 0, kind: "build", started: T0 + 60, size: 5),
    Job.new(id: 2, parent: 1, kind: "build", started: T0, size: 7),
    Job.new(id: 3, parent: 1, kind: "test", started: T0 + 120, size: nil),
    Job.new(id: 4, parent: 0, kind: "test", started: nil, size: nil)
  ].freeze

  def define_jobs
    R2UI.resource :job do
      source { JOBS }
      key :id, parent: :parent
      group_by :kind
      group_by :parent, tree: true
      index do
        column :id, format: :id
        column :kind
        column :started, format: :age
        column :size, format: :integer, aggregate: :max
      end
    end
  end

  def test_min_and_max_aggregates_compact_values
    jobs = define_jobs
    lines = R2UI::Query.new(jobs, JOBS, grouping: jobs.groupings.first, sort: [:kind, :asc]).lines
    build, test = lines

    assert_equal "build", build.label
    assert_equal T0, build.values[:started], "age groups show the oldest member"
    assert_equal 7, build.values[:size]
    assert_equal T0 + 120, test.values[:started], "nils are skipped"
    assert_nil test.values[:size], "nil when no member has a value"
  end

  def test_tree_keeps_own_value_for_min_and_max
    jobs = define_jobs
    lines = R2UI::Query.new(jobs, JOBS, grouping: jobs.groupings.last, sort: [:id, :asc]).lines
    root = lines.find { |l| l.id == 1 }

    assert_equal T0 + 60, root.values[:started]
    assert_equal 5, root.values[:size]
  end

  def test_sorting_by_an_age_column_sorts_by_time
    jobs = define_jobs
    asc = R2UI::Query.new(jobs, JOBS, sort: [:started, :asc]).lines
    assert_equal [2, 1, 3, 4], asc.map(&:id), "oldest first, missing last"

    desc = R2UI::Query.new(jobs, JOBS, sort: [:started, :desc]).lines
    assert_equal [3, 1, 2, 4], desc.map(&:id)
  end

  def test_tree_inside_scope_makes_orphans_roots
    lines = query(scope: @resource.default_scope, grouping: @resource.groupings.last, sort: [:pid, :asc])
    assert_equal [10, 11, 12, 20, 21], lines.map(&:id)
    assert_equal [0, 1, 2, 0, 1], lines.map(&:depth)
  end
end
