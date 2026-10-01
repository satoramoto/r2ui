# frozen_string_literal: true

require "test_helper"

class AppTest < Minitest::Test
  def setup
    R2UI.reset!
    Fixtures.define_processes
    R2UI.resource :memory do
      source { { used: 24 * 1024**3, total: 32 * 1024**3, pressure: 36.0 } }
      attribute :used, format: :bytes
      attribute :total, format: :bytes
      attribute :pressure, format: :percent
    end
    @killed = []
    killed = @killed
    R2UI.registry.resource(:process).actions << R2UI::DSL::Action.new(
      name: :kill, label: "Kill", key: "K", confirm: true, handler: ->(p) { killed << p.pid }
    )
    R2UI.dashboard do
      row height: 6 do
        panel :memory do
          gauge :used, of: :total
          sparkline :pressure, height: 1
        end
      end
      row { panel :process }
    end
  end

  def app
    @app ||= R2UI::App.new(R2UI.registry).tap { |a| a.snapshot(width: 100, height: 20) }
  end

  def text = app.frame(100, 20).plain_lines.join("\n")

  def test_dashboard_renders_panels_and_status
    assert_match(/Memory/, text)
    assert_match(/24G \/ 32G 75%/, text)
    assert_match(/\[Agents\]/, text)
    assert_match(/cargo/, text)
    refute_match(/launchd/, text, "default scope hides it")
    assert_match(/sort: Cpu▼/, text)
  end

  def test_keys_change_scope_grouping_and_search
    app.press("]")
    assert_match(/launchd/, text)

    app.press("g")
    assert_match(/group: Name/, text)

    app.press("/", "c", "o", "d", :enter)
    assert_match(/codex/, text)
    refute_match(/cargo/, text)
  end

  def test_tree_mode_folds
    app.press("]", "g", "g", "g")
    assert_match(/group: Parent/, text)
    assert_match(/▾ launchd \(6\)/, text)

    app.press(:enter)
    assert_match(/▸ launchd/, text)
    refute_match(/claude/, text)
  end

  def test_action_asks_then_runs
    text
    app.press("K")
    assert_match(/Kill 1 row\? y\/n/, text)
    app.press("y")
    assert_equal [12], @killed
    assert_match(/Kill: 1 done/, text)
  end
end
