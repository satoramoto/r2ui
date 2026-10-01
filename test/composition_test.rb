# frozen_string_literal: true

require "test_helper"

# v0.3: dashboards and resources assembled from several files, in any load order.
class CompositionTest < Minitest::Test
  def setup = R2UI.reset!

  def define_base
    R2UI.resource(:fruit) do
      source { [{ name: "apple", n: 1 }] }
      column :name
    end
    R2UI.dashboard do
      title "Shop"
      row(:top, height: 5) { panel :clock, resource: nil, order: 20 do view { "clock" } end }
      row(:main) { panel :fruit }
    end
  end

  def panel_names(dashboard) = dashboard.rows.map { |r| r.panels.map(&:name) }

  def test_extend_dashboard_adds_panels_to_a_named_row_by_order
    define_base
    R2UI.dashboard(extend: true) do
      row(:top) { panel(:memory, resource: nil, order: 10) { view { "mem" } } }
    end
    R2UI.panel(:disk, row: :top, order: 30, resource: nil) { view { "disk" } }

    dashboard = R2UI.registry.dashboards[:main]
    assert_equal [%i[memory clock disk], %i[fruit]], panel_names(dashboard)
    assert_equal 5, dashboard.rows.first.height, "extending keeps the row's height"
    assert_equal "Shop", dashboard.title
    frame = R2UI::App.new(R2UI.registry).frame(90, 12).plain_lines.join("\n")
    assert_includes frame, "mem"
    assert_includes frame, "disk"
  end

  def test_extensions_loaded_before_the_definition_still_apply
    R2UI.panel(:memory, row: :top, order: 10, resource: nil) { view { "mem" } }
    R2UI.resource(:fruit, extend: true) { column :n, format: :integer }
    define_base

    assert_equal [%i[memory clock], %i[fruit]], panel_names(R2UI.registry.dashboards[:main])
    assert_equal %i[name n], R2UI.registry.resource(:fruit).columns.map(&:key)
  end

  def test_extend_resource_adds_actions_and_scopes
    define_base
    R2UI.resource(:fruit, extend: true) do
      scope(:apples) { |r| r[:name] == "apple" }
      action(:eat, key: "e") { |_row| nil }
    end

    resource = R2UI.registry.resource(:fruit)
    assert_equal [:apples], resource.scopes.map(&:name)
    assert_equal ["e"], resource.actions.map(&:key)
  end

  def test_redefining_from_another_place_raises
    define_base
    error = assert_raises(R2UI::Error) { R2UI.resource(:fruit) { source { [] } } }
    assert_match(/already defined at .*composition_test\.rb:\d+.*extend: true/, error.message)
    assert_raises(R2UI::Error) { R2UI.dashboard { row { panel :fruit } } }
    assert_equal %i[name], R2UI.registry.resource(:fruit).columns.map(&:key), "a refused definition changes nothing"
  end

  def test_replace_true_replaces
    define_base
    R2UI.resource(:fruit, replace: true) { source { [] } }
    assert_empty R2UI.registry.resource(:fruit).columns
  end

  def test_the_same_definition_loaded_twice_replaces_itself
    2.times do
      R2UI.resource(:fruit) { source { [] } }
      R2UI.panel(:a, row: :top, resource: nil) { view { "a" } }
      R2UI.dashboard(extend: true) { row(:top) { panel(:b, resource: nil) { view { "b" } } } }
    end
    assert_equal [%i[a b]], panel_names(R2UI.registry.dashboards[:main])
  end

  def test_extensions_survive_redefinition_from_the_same_place
    2.times do |i|
      R2UI.resource(:fruit) { source { [] } } # same line each time
      R2UI.resource(:fruit, extend: true) { column :name } if i.zero?
    end
    assert_equal %i[name], R2UI.registry.resource(:fruit).columns.map(&:key)
  end

  def test_a_failing_block_leaves_the_registry_unchanged
    define_base
    assert_raises(R2UI::Error) { R2UI.panel(:fruit, row: :top) } # name already on the dashboard
    assert_equal [%i[clock], %i[fruit]], panel_names(R2UI.registry.dashboards[:main])
    assert_raises(R2UI::Error) { R2UI.resource(:veg) {} }
    assert_raises(R2UI::Error) { R2UI.registry.resource(:veg) }
  end

  def test_rows_order_and_panel_without_a_row
    define_base
    R2UI.dashboard(extend: true) { row(:footer, height: 1, order: 10) { panel(:keys, resource: nil) { view { "k" } } } }
    R2UI.dashboard(extend: true) { row(:header, height: 1, order: -10) { panel(:head, resource: nil) { view { "h" } } } }
    R2UI.panel(:alone, resource: nil) { view { "x" } }
    assert_equal [%i[head], %i[clock], %i[fruit], %i[alone], %i[keys]], panel_names(R2UI.registry.dashboards[:main])
  end

  def test_a_declared_row_without_panels_takes_no_space
    define_base
    R2UI.dashboard(extend: true) { row(:sidebar, height: 10) }
    assert_equal [%i[clock], %i[fruit]], panel_names(R2UI.registry.dashboards[:main])
    R2UI.panel(:later, row: :sidebar, resource: nil) { view { "l" } }
    assert_equal 10, R2UI.registry.dashboards[:main].rows.last.height
  end

  def test_focus_picks_the_initial_panel
    define_base
    R2UI.dashboard(extend: true) { focus :clock }
    assert_equal :clock, R2UI::App.new(R2UI.registry).focus.name

    R2UI.dashboard(extend: true) { focus :nope }
    assert_raises(R2UI::Error) { R2UI::App.new(R2UI.registry) }
  end

  def test_default_focus_is_still_the_first_table
    define_base
    assert_equal :fruit, R2UI::App.new(R2UI.registry).focus.name
  end

  def test_add_dashboard_with_a_built_object_still_replaces_and_extensions_copy_it
    built = R2UI::DSL::Dashboard.build(:main) { row(:top) { panel(:a, resource: nil) { view { "a" } } } }
    R2UI.registry.add_dashboard(built)
    R2UI.panel(:b, row: :top, resource: nil) { view { "b" } }
    assert_equal [%i[a b]], panel_names(R2UI.registry.dashboards[:main])
    assert_equal [%i[a]], panel_names(built), "the caller's object is not changed"
    R2UI.registry.add_dashboard(R2UI::DSL::Dashboard.build(:main) { row(:top) { panel(:c, resource: nil) { view { "c" } } } })
    assert_equal [%i[c b]], panel_names(R2UI.registry.dashboards[:main])
  end

  def test_with_registry_scopes_definitions
    global = R2UI.registry
    registry = R2UI.with_registry { R2UI.resource(:fruit) { source { [] } } }
    assert_same global, R2UI.registry
    assert registry.resources.key?(:fruit)
    refute global.resources.key?(:fruit)
  end

  def test_panel_width_is_recorded
    R2UI.dashboard { row { panel(:detail, resource: nil, width: 40) { view { "d" } } } }
    assert_equal 40, R2UI.registry.dashboards[:main].panels.first.width
  end
end
