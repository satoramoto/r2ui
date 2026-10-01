# frozen_string_literal: true

require "test_helper"

# s32-screen: a dashboard with no rows that draws its whole view from one block.
class ScreenTest < Minitest::Test
  def setup
    R2UI.reset!
    # Stands in for an `on_key` / `on` binding (s03, s04): any `on` handler sees the keys.
    R2UI.extension :screen_test_counter do
      on(->(msg) { msg.is_a?(Bubbletea::KeyMessage) && %w[+ -].include?(R2UI::Keys.name(msg)) }) do |msg|
        state[:count] += R2UI::Keys.name(msg) == "+" ? 1 : -1
      end
    end
    R2UI.dashboard do
      screen { |width, height| "count: #{state[:count]}\n#{width}x#{height}\npress q to quit" }
    end
    @app = R2UI::App.new(R2UI.registry)
    @app.state[:count] = 0
  end

  def teardown
    R2UI::Extensions.remove(:screen_test_counter)
    @app&.stop
  end

  def quit?(command)
    commands = command.is_a?(Bubbletea::BatchCommand) ? command.commands : [command]
    commands.any?(Bubbletea::QuitCommand)
  end

  def test_the_view_is_the_blocks_string_at_the_window_size
    @app.init
    @app.update(Bubbletea::WindowSizeMessage.new(width: 100, height: 30))

    assert_equal "count: 0\n100x30\npress q to quit", @app.view
  end

  def test_no_panels_or_status_bar_are_drawn
    @app.init

    refute_match(/[╭│]/, @app.view)
    refute_match(/zoom|tab panel/, @app.view)
  end

  def test_keys_reach_on_handlers_and_the_view_follows_state
    @app.init
    @app.press("+", "+", "-", "+")

    assert_equal 2, @app.state[:count]
    assert_match(/\Acount: 2$/, @app.view)
  end

  def test_q_and_ctrl_c_quit
    @app.init

    assert quit?(@app.press("q").last)
    assert quit?(@app.press("ctrl+c").last)
  end

  def test_core_navigation_keys_are_harmless_without_panels
    @app.init

    assert_empty @app.press(:tab, :back_tab, "z", :up, :down, "s", :enter)
    assert_match(/\Acount: 0$/, @app.view)
  end

  def test_a_block_may_ignore_the_size
    R2UI.dashboard(:plain) { screen { "hello" } }

    assert_equal "hello", R2UI::App.new(R2UI.registry, :plain).view
  end

  def test_dashboards_without_screen_draw_as_before
    R2UI.dashboard(:panels) { row { panel(:hi, resource: nil) { view { "hi there" } } } }

    plain = R2UI::App.new(R2UI.registry, :panels).view.gsub(/\e\[[0-9;]*m/, "")

    assert_match(/│hi there/, plain)
    assert_match(/z zoom/, plain)
  end

  def test_needs_a_block_and_only_one_screen
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { screen } }
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { screen { "a" } and screen { "b" } } }
  end

  def test_a_screen_dashboard_cannot_also_have_rows
    R2UI.dashboard(:mixed) do
      screen { "mine" }
      row { panel(:hi, resource: nil) { view { "hi" } } }
    end

    assert_raises(R2UI::Error) { R2UI::App.new(R2UI.registry, :mixed) }
  end
end
