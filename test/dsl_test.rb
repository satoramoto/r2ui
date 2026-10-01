# frozen_string_literal: true

require "test_helper"

class DslTest < Minitest::Test
  def setup = R2UI.reset!

  def test_resource_records_declarations
    resource = Fixtures.define_processes

    assert_equal %i[agents all], resource.scopes.map(&:name)
    assert_equal :agents, resource.default_scope.name
    assert_equal %i[name cwd parent], resource.groupings.map(&:name)
    assert resource.groupings.last.tree?
    assert_equal %i[pid name cwd cpu rss], resource.columns.map(&:key)
    assert_equal [:cpu, :desc], resource.default_sort
    assert_equal "Memory", resource.column(:rss).label
    assert_equal :count, resource.column(:pid).aggregate
    assert_equal :sum, resource.column(:cpu).aggregate
  end

  def test_resource_without_source_is_an_error
    error = assert_raises(R2UI::Error) { R2UI.resource(:empty) { scope :all } }
    assert_match(/source/, error.message)
  end

  def test_tree_grouping_needs_parent_key
    error = assert_raises(R2UI::Error) do
      R2UI.resource(:t) do
        source { [] }
        group_by :parent, tree: true
      end
    end
    assert_match(/parent/, error.message)
  end

  def test_refresh_accepts_anything_with_to_f
    resource = R2UI.resource(:r) do
      source { [] }
      refresh every: Rational(1, 2)
    end
    assert_in_delta 0.5, resource.interval
  end

  def test_dashboard_layout
    Fixtures.define_processes
    dashboard = R2UI.dashboard do
      row height: 10 do
        panel :busy, resource: :process, span: 2 do
          table scope: :all, group_by: :name, limit: 3
        end
      end
      row { panel :process }
    end

    assert_equal [10, nil], dashboard.rows.map(&:height)
    busy, full = dashboard.panels
    assert_equal :process, busy.resource
    assert_equal 2, busy.span
    assert_equal :name, busy.table.group_by
    assert_instance_of R2UI::DSL::Table, full.table
  end

  def test_screen_defaults_to_first_resource
    Fixtures.define_processes
    assert_equal :process, R2UI.registry.screen.panels.first.resource
  end
end
