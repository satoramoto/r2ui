# frozen_string_literal: true

require "test_helper"
require_relative "../compat/bubbletea/pty_helper"

# s13-screen-mode: `inline height: N` runs without the alt screen at N lines; `enter_alt_screen` /
# `exit_alt_screen` switch at runtime.
class ScreenModeTest < Minitest::Test
  ALT_ON = "\e[?1049h"
  ALT_OFF = "\e[?1049l"

  def setup
    R2UI.reset!
  end

  def app_for(&)
    R2UI.dashboard(&)
    R2UI::App.new(R2UI.registry)
  end

  def test_default_dashboard_uses_the_alt_screen
    app = app_for { row { panel(:body, resource: nil) { view { "hi" } } } }

    assert_equal true, app.program_options[:alt_screen]
  end

  def test_inline_turns_the_alt_screen_off
    app = app_for do
      inline height: 10
      row { panel(:body, resource: nil) { view { "hi" } } }
    end

    assert_equal false, app.program_options[:alt_screen]
  end

  def test_inline_draws_height_lines_whatever_the_terminal_height
    app = app_for do
      inline height: 10
      row { panel(:body, resource: nil) { view { "hi" } } }
    end
    app.update(Bubbletea::WindowSizeMessage.new(width: 50, height: 40))

    assert_equal [50, 10], app.frame_size
    assert_equal 10, app.view.lines.size
  end

  def test_inline_keeps_the_terminal_width
    app = app_for do
      inline height: 6
      row { panel(:body, resource: nil) { view { "hi" } } }
    end
    app.update(Bubbletea::WindowSizeMessage.new(width: 33, height: 24))

    assert_equal 33, app.frame_size.first
  end

  def test_inline_needs_a_positive_integer_height
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { inline height: 0 } }
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { inline height: -3 } }
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { inline } }
  end

  def test_enter_and_exit_alt_screen_enqueue_bubbletea_commands
    app = app_for { row { panel(:body, resource: nil) { view { "hi" } } } }
    ctx = R2UI::Context.new(app)

    assert_kind_of Bubbletea::EnterAltScreenCommand, ctx.enter_alt_screen
    assert_kind_of Bubbletea::ExitAltScreenCommand, ctx.exit_alt_screen
    assert_equal [Bubbletea::EnterAltScreenCommand, Bubbletea::ExitAltScreenCommand], ctx.commands.commands.map(&:class)
  end

  INLINE_APP = <<~RUBY
    require "r2ui"
    R2UI.dashboard do
      inline height: 4
      every(0.05) { state[:n] = state[:n].to_i + 1 }
      row { panel(:body, resource: nil) { view { "inline-frame \#{state[:n].to_i >= 2 ? "ready" : "wait"}" } } }
    end
    R2UI.run
  RUBY

  def test_pty_inline_never_enters_the_alt_screen_and_leaves_the_last_frame
    run = PtyHelper.run(INLINE_APP, load_path: [PtyHelper::LIB], width: 50, height: 20) do |driver|
      driver.wait_for("inline-frame ready")
      driver.type("q")
    end

    assert run.status.success?, run.output.inspect
    assert run.tty_restored, "terminal left in raw mode"
    refute_includes run.output, ALT_ON
    refute_includes run.output, ALT_OFF
    assert_includes run.output, "inline-frame ready"
    assert run.output.rindex("inline-frame ready") > run.output.rindex("inline-frame wait").to_i,
           "last frame not drawn"
  end

  SWITCH_APP = <<~RUBY
    require "r2ui"
    R2UI.dashboard do
      row { panel(:body, resource: nil) { view { "switch-frame" } } }
    end
    # No on_key yet (another story): switch from a timer.
    R2UI.extension :switch_driver do
      init { command(Bubbletea.tick(0.3) { Class.new(Bubbletea::Message).new }) }
      on(->(m) { m.is_a?(Bubbletea::Message) && !m.is_a?(Bubbletea::KeyMessage) && !m.is_a?(Bubbletea::WindowSizeMessage) && m.class.name.nil? }) do |_m|
        store(:n)[:n] = store(:n)[:n].to_i + 1
        if store(:n)[:n] == 1
          exit_alt_screen
          command(Bubbletea.tick(0.3) { Class.new(Bubbletea::Message).new })
        else
          enter_alt_screen
        end
      end
    end
    R2UI.run
  RUBY

  def test_pty_helpers_switch_screens_at_runtime
    run = PtyHelper.run(SWITCH_APP, load_path: [PtyHelper::LIB], width: 50, height: 12) do |driver|
      driver.wait_for(ALT_ON)
      driver.wait_for(ALT_OFF)
      driver.pause(0.6)
      driver.type("q")
    end

    assert run.status.success?, run.output.inspect
    assert run.tty_restored
    first_on = run.output.index(ALT_ON)
    off = run.output.index(ALT_OFF)
    second_on = run.output.index(ALT_ON, off.to_i + 1)
    assert first_on && off && first_on < off, run.output.inspect
    assert second_on, "never re-entered the alt screen: #{run.output.inspect}"
  end
end
