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

  # --- frame_due?: the runner draws a frame slot only when this says so ---

  def clocked_app
    @t = 0.0
    R2UI::App.new(R2UI.registry).tap { |a| a.motion.clock = -> { @t } }
  end

  def test_frame_is_due_only_after_a_change
    a = clocked_app
    assert a.frame_due?, "nothing drawn yet"
    a.view
    refute a.frame_due?, "fresh app, just drawn"

    a.press("j")
    assert a.frame_due?, "an update ran"
    a.view
    refute a.frame_due?

    a.init
    assert a.frame_due?, "init counts as an update"
    a.stop
    a.view

    a.feeds[:process].refresh!
    assert a.frame_due?, "a feed has new data"
    a.view
    refute a.frame_due?

    @t = R2UI::App::IDLE_FRAME + 0.01
    assert a.frame_due?, "idle for longer than IDLE_FRAME"
    a.view
    refute a.frame_due?
  end

  def test_frame_is_due_while_motion_is_active_or_a_flash_shows
    a = clocked_app
    a.view
    a.motion.hold(0.5)
    assert a.frame_due?, "motion active"
    a.view
    @t = 0.5 + R2UI::Motion::GRACE + 0.1
    a.view
    refute a.frame_due?, "the hold ended"

    a.flash("saved")
    a.view
    assert a.frame_due?, "the flash is showing"
    a.instance_variable_set(:@flash_at, Time.now - R2UI::App::FLASH_SECONDS - 1)
    assert a.frame_due?, "the flash expired since the last view"
    a.view
    refute a.frame_due?
  end

  def test_view_sweeps_stale_motion_keys_at_most_once_a_second
    a = clocked_app
    a.motion.tween(:a, 1)
    a.motion.tween(:b, 1)
    @t = 29.5
    a.view
    @t = 30.2
    a.view
    assert_in_delta 1.0, a.motion.tween(:a, 5), 1e-9, "not swept: within a second of the last sweep"
    @t = 30.6
    a.view
    assert_in_delta 5.0, a.motion.tween(:b, 5), 1e-9, "swept: unseen for 30 s"
  end
end
