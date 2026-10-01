# frozen_string_literal: true

require "test_helper"

# s16-focus-report: terminal focus in/out (Bubbletea's ReportFocus, FocusMsg and BlurMsg).
class FocusReportTest < Minitest::Test
  def setup = R2UI.reset!

  def app_for(&definition)
    R2UI.dashboard do
      instance_eval(&definition)
      row { panel(:focus, resource: nil) { view { "focused: #{state[:terminal_focused]}" } } }
    end
    R2UI::App.new(R2UI.registry)
  end

  def test_report_focus_turns_on_focus_reporting
    app = app_for { report_focus }

    assert app.program_options[:report_focus]
    assert app.program_options[:alt_screen], "other runner options stay"
  end

  def test_focus_reporting_is_off_without_the_keyword
    app = app_for { nil }

    refute app.program_options[:report_focus]
  end

  def test_terminal_focused_is_true_at_start
    app = app_for { report_focus }

    assert_equal true, app.state[:terminal_focused]
    assert_match(/focused: true/, app.frame(40, 5).plain_lines.join("\n"))
  end

  def test_blur_and_focus_messages_track_state
    app = app_for { report_focus }
    app.init

    app.update(Bubbletea::BlurMessage.new)
    assert_equal false, app.state[:terminal_focused]
    assert_match(/focused: false/, app.view)

    app.update(Bubbletea::FocusMessage.new)
    assert_equal true, app.state[:terminal_focused]
  ensure
    app.stop
  end

  def test_on_focus_and_on_blur_run_their_blocks_and_commands
    app = app_for do
      report_focus
      on_focus { state[:events] = [*state[:events], :focus] }
      on_blur do
        state[:events] = [*state[:events], :blur]
        flash "away"
        Bubbletea.quit
      end
    end
    app.init

    _, command = app.update(Bubbletea::BlurMessage.new)
    assert_kind_of Bubbletea::QuitCommand, command
    assert_match(/away/, app.frame(40, 5).plain_lines.join("\n"))
    assert_equal false, app.state[:terminal_focused], "state is updated before the block runs"

    app.update(Bubbletea::FocusMessage.new)
    assert_equal %i[blur focus], app.state[:events]
  ensure
    app.stop
  end

  def test_several_handlers_run_in_order
    app = app_for do
      report_focus
      on_focus { (state[:seen] ||= []) << 1 }
      on_focus { (state[:seen] ||= []) << 2 }
    end
    app.init

    app.update(Bubbletea::FocusMessage.new)

    assert_equal [1, 2], app.state[:seen]
  ensure
    app.stop
  end

  def test_handlers_need_a_block
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { on_focus } }
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { on_blur } }
  end
end
