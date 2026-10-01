# frozen_string_literal: true

require "test_helper"

# s24-viewport: a panel hosting a Bubbles::Viewport over a block's text.
class ViewportTest < Minitest::Test
  def setup
    R2UI.reset!
    R2UI::Component.require_bubbles!
  end

  def text(app, width = 40, height = 8) = app.frame(width, height).plain_lines.join("\n")

  def lines(count, from = 1) = (from...(from + count)).map { |i| "line #{i}" }.join("\n")

  def wheel(button)
    Bubbletea::MouseMessage.new(x: 2, y: 2, button:, action: Bubbletea::MouseMessage::ACTION_PRESS)
  end

  def log_app(follow: false)
    R2UI.dashboard do
      row do
        panel :log, resource: nil do
          viewport(:log, follow:) { state[:log].join("\n") }
        end
      end
    end
    app = R2UI::App.new(R2UI.registry)
    app.state[:log] = (1..30).map { |i| "line #{i}" }
    app
  end

  def first_line(app) = text(app)[/│(line \d+)/, 1]

  def test_hosts_a_viewport_sized_to_the_panel_showing_the_text
    app = log_app
    out = text(app)

    assert_kind_of Bubbles::Viewport, app.component(:log)
    assert_equal [38, 5], [app.component(:log).width, app.component(:log).height],
                 "inner size of a 40x8 frame: box borders and the status bar"
    assert_match(/│line 1 /, out)
    assert_match(/│line 5 /, out)
    refute_match(/line 6/, out)
  end

  def test_scroll_keys_move_it_while_its_panel_is_focused
    app = log_app
    text(app)

    app.press(:down)
    assert_equal "line 2", first_line(app)
    app.press(:page_down)
    assert_equal "line 7", first_line(app)
    app.press(:up)
    assert_equal "line 6", first_line(app)
    app.press(:page_up)
    assert_equal "line 1", first_line(app)
  end

  def test_text_is_re_read_each_frame_keeping_the_scroll_position
    app = log_app
    text(app)
    app.press(:page_down)

    app.state[:log] = app.state[:log].map(&:upcase)

    assert_match(/│LINE 6 /, text(app))
    refute_match(/LINE 1 /, text(app))
  end

  def test_other_keys_still_reach_the_rest_of_the_app
    app = log_app
    text(app)

    assert_kind_of Bubbletea::QuitCommand, app.press("q").first
  end

  def test_keys_leave_it_alone_when_another_panel_is_focused
    R2UI.dashboard do
      row do
        panel(:other, resource: nil) { view { "other" } }
        panel(:log, resource: nil) { viewport(:log) { (1..30).map { |i| "line #{i}" }.join("\n") } }
      end
    end
    app = R2UI::App.new(R2UI.registry)
    text(app, 80, 8)

    app.press(:down, :page_down)

    assert_equal 0, app.component(:log).y_offset
    app.press(:tab, :down)
    assert_equal 1, app.component(:log).y_offset
  end

  def test_mouse_wheel_scrolls_it_while_focused
    app = log_app
    text(app)

    app.update(wheel(Bubbletea::MouseMessage::BUTTON_WHEEL_DOWN))
    assert_equal "line 4", first_line(app), "the bubbles wheel delta is 3 lines"
    app.update(wheel(Bubbletea::MouseMessage::BUTTON_WHEEL_UP))
    assert_equal "line 1", first_line(app)
  end

  def test_follow_sticks_to_the_bottom_as_the_text_grows
    app = log_app(follow: true)

    assert_match(/│line 30 /, text(app))
    app.state[:log] += ["line 31", "line 32"]
    assert_match(/│line 32 /, text(app))
    assert_equal "line 28", first_line(app)

    app.press(:up)
    app.state[:log] << "line 33"
    assert_equal "line 27", first_line(app), "scrolled up: stays put while text grows"

    app.press(:end)
    app.state[:log] << "line 34"
    assert_match(/│line 34 /, text(app), "back at the bottom: follows again")
  end

  def test_without_follow_it_stays_at_the_top
    app = log_app
    text(app)
    app.state[:log] += ["line 31"]

    assert_equal "line 1", first_line(app)
  end

  def test_needs_a_block
    assert_raises(ArgumentError) do
      R2UI.dashboard(:bad) { row { panel(:log, resource: nil) { viewport(:log) } } }
    end
  end
end
