# frozen_string_literal: true

require "test_helper"

# s30-stopwatch: `stopwatch :name, autostart: true` hosts a Bubbles::Stopwatch; while its panel is
# focused `s` starts/stops it and `r` resets it.
class StopwatchTest < Minitest::Test
  def setup
    R2UI.reset!
  end

  def teardown
    @app&.stop
  end

  def build(autostart: true)
    R2UI.dashboard do
      row do
        panel :lap, resource: nil do
          stopwatch :lap, autostart:
        end
        panel :other, resource: nil do
          view { "other" }
        end
      end
    end
    @app = R2UI::App.new(R2UI.registry)
  end

  # Runs a command the way the runner would, without waiting: messages it sends go back through
  # `update` (and their commands run too); ticks are returned so a test can fire them.
  def drive(command, ticks = [])
    case command
    when Bubbletea::BatchCommand, Bubbletea::SequenceCommand then command.commands.each { |c| drive(c, ticks) }
    when Bubbletea::SendMessage then drive(@app.update(command.message).last, ticks)
    when Bubbletea::TickCommand then ticks << command
    end
    ticks
  end

  def fire(ticks) = ticks.flat_map { |t| drive(@app.update(t.callback.call).last) }

  # One second passes: the first pending tick fires. (Starting a bubbles stopwatch schedules two
  # tag-0 ticks, one from `start` and one from its StartStopMessage; that is upstream behavior.)
  def one_second(ticks) = fire([ticks.shift])

  def watch = @app.component(:lap)
  def text = @app.frame(60, 6).plain_lines.join("\n")

  def panel(name) = @app.dashboard.panels.find { |p| p.name == name }

  def test_autostart_starts_counting_at_init
    build
    ticks = drive(@app.init.last)

    assert_kind_of Bubbles::Stopwatch, watch
    assert_predicate watch, :running?
    assert_match(/0:00\.00/, text)

    one_second(ticks)
    assert_match(/0:01\.00/, text)
  end

  def test_without_autostart_it_waits_stopped
    build(autostart: false)
    ticks = drive(@app.init.last)

    assert_empty ticks
    refute_predicate watch, :running?
    assert_match(/0:00\.00/, text)
  end

  def test_s_starts_and_stops_while_focused
    build(autostart: false)
    drive(@app.init.last)

    ticks = @app.press("s").flat_map { |c| drive(c) }
    assert_predicate watch, :running?
    ticks.concat(one_second(ticks))
    assert_match(/0:01\.00/, text)

    @app.press("s").each { |c| drive(c) }
    refute_predicate watch, :running?
    assert_empty fire(ticks), "a stopped stopwatch schedules no further ticks"
    assert_match(/0:01\.00/, text)
  end

  def test_r_resets_while_focused
    build
    one_second(drive(@app.init.last))
    assert_match(/0:01\.00/, text)

    @app.press("r").each { |c| drive(c) }

    assert_equal 0.0, watch.elapsed
    assert_match(/0:00\.00/, text)
  end

  def test_keys_do_nothing_when_another_panel_is_focused
    build(autostart: false)
    drive(@app.init.last)
    @app.focus = panel(:other)

    @app.press("s").each { |c| drive(c) }

    refute_predicate watch, :running?
  end

  def test_other_keys_still_reach_the_core
    build
    drive(@app.init.last)

    assert_includes @app.press("q").map(&:class), Bubbletea::QuitCommand
  end

  def test_hints_show_while_focused
    build
    pairs = @app.hint_pairs

    assert_includes pairs, ["s", "start/stop"]
    assert_includes pairs, ["r", "reset"]

    @app.focus = panel(:other)
    refute_includes @app.hint_pairs, ["s", "start/stop"]
  end

  def test_needs_a_name
    assert_raises(ArgumentError) do
      R2UI.dashboard { row { panel(:x, resource: nil) { stopwatch "lap" } } }
    end
  end
end
