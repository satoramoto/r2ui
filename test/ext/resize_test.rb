# frozen_string_literal: true

require "test_helper"

# s17-resize: dashboard `on_resize` and `min_size`.
class ResizeTest < Minitest::Test
  def setup = R2UI.reset!

  def size(width, height) = Bubbletea::WindowSizeMessage.new(width:, height:)

  def build(&block)
    R2UI.dashboard do
      on_resize { |w, h| state[:sizes] = (state[:sizes] || []) << [w, h] }
      instance_exec(&block) if block
      row do
        panel :hello, resource: nil do
          view { "dashboard body" }
        end
      end
    end
    R2UI::App.new(R2UI.registry)
  end

  def test_on_resize_runs_with_width_and_height_on_every_window_size_message
    app = build

    app.update(size(120, 40))
    app.update(size(90, 30))

    assert_equal [[120, 40], [90, 30]], app.state[:sizes]
  end

  def test_on_resize_runs_for_the_first_message_too
    app = build

    app.update(size(100, 25))

    assert_equal [[100, 25]], app.state[:sizes]
  end

  def test_on_resize_does_not_run_for_other_messages
    app = build

    app.press("j", :down)

    assert_nil app.state[:sizes]
  end

  def test_on_resize_block_can_drive_state_the_dashboard_reads
    R2UI.dashboard do
      on_resize { |w, _h| state[:narrow] = w < 100 }
      row { panel(:p, resource: nil) { view { state[:narrow] ? "narrow" : "wide" } } }
    end
    app = R2UI::App.new(R2UI.registry)

    app.update(size(80, 24))
    assert_match(/narrow/, app.view)

    app.update(size(120, 24))
    assert_match(/wide/, app.view)
  end

  def test_on_resize_block_may_return_a_command
    R2UI.dashboard do
      on_resize { |_w, _h| quit }
      row { panel(:p, resource: nil) { view { "x" } } }
    end
    app = R2UI::App.new(R2UI.registry)

    _, command = app.update(size(80, 24))

    assert_includes [command, *(command.respond_to?(:commands) ? command.commands : [])].map(&:class), Bubbletea::QuitCommand
  end

  def test_min_size_shows_the_too_small_view_when_the_width_is_short
    app = build { min_size 80, 20 }

    app.update(size(70, 30))

    assert_match(/terminal too small \(70x30, need 80x20\)/, app.view)
    refute_match(/dashboard body/, app.view)
  end

  def test_min_size_shows_the_too_small_view_when_the_height_is_short
    app = build { min_size 80, 20 }

    app.update(size(100, 10))

    assert_match(/terminal too small \(100x10, need 80x20\)/, app.view)
  end

  def test_min_size_message_is_centered
    app = build { min_size 80, 20 }
    app.update(size(70, 11))

    lines = app.view.split("\n")
    message = lines.index { |l| l.include?("terminal too small") }

    assert_equal 5, message, "vertically centered in 11 rows"
    text = lines[message]
    left = text[/\A */].length
    right = 70 - text.rstrip.length
    assert_in_delta left, right, 1
  end

  def test_min_size_shows_the_dashboard_at_exactly_the_minimum
    app = build { min_size 80, 20 }

    app.update(size(80, 20))

    assert_match(/dashboard body/, app.view)
    refute_match(/too small/, app.view)
  end

  def test_min_size_recovers_when_the_window_grows
    app = build { min_size 80, 20 }

    app.update(size(40, 10))
    assert_match(/too small/, app.view)

    app.update(size(120, 40))
    assert_match(/dashboard body/, app.view)
  end

  def test_without_min_size_a_small_window_still_draws_the_dashboard
    app = build

    app.update(size(30, 8))

    refute_match(/too small/, app.view)
  end

  def test_on_resize_still_runs_while_the_window_is_too_small
    app = build { min_size 80, 20 }

    app.update(size(40, 10))

    assert_equal [[40, 10]], app.state[:sizes]
  end

  def test_keywords_validate_their_arguments
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { on_resize } }
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { min_size 0, 20 } }
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { min_size 80, -1 } }
  end
end
