# frozen_string_literal: true

require "test_helper"

# s01-every, the reference extension. A story's test copies this shape: build an app from a DSL
# definition, drive it through the Bubbletea model interface (init / update / view), and assert
# what the user sees and which commands come back.
class EveryTest < Minitest::Test
  def setup
    R2UI.reset!
    R2UI.dashboard do
      every 5 do
        state[:fired] = state[:fired].to_i + 1
        flash "fired #{state[:fired]}"
      end
      every(Rational(1, 2)) { quit if state[:fired].to_i >= 2 }

      row do
        panel :ticks, resource: nil do
          view { "fired: #{state[:fired].to_i}" }
        end
      end
    end
    @app = R2UI::App.new(R2UI.registry)
  end

  def ticks(command) = command.is_a?(Bubbletea::BatchCommand) ? command.commands : [command]

  def test_init_schedules_one_tick_per_timer
    _, command = @app.init
    assert_equal [5.0, 0.5], ticks(command).map(&:duration)
  ensure
    @app.stop
  end

  def test_tick_runs_the_block_and_schedules_the_next
    _, command = @app.init
    five, = ticks(command)

    _, next_command = @app.update(five.callback.call)

    assert_equal 1, @app.state[:fired]
    assert_kind_of Bubbletea::TickCommand, next_command
    assert_equal 5.0, next_command.duration
    assert_match(/fired 1/, @app.frame(40, 5).plain_lines.join("\n"))
    assert_match(/fired: 1/, @app.view)
  ensure
    @app.stop
  end

  def test_block_commands_are_returned_with_the_next_tick
    _, command = @app.init
    five, half = ticks(command)
    @app.update(five.callback.call)
    @app.update(five.callback.call)

    _, out = @app.update(half.callback.call)

    assert_kind_of Bubbletea::BatchCommand, out
    assert_equal [Bubbletea::QuitCommand, Bubbletea::TickCommand], out.commands.map(&:class)
  ensure
    @app.stop
  end

  def test_ticks_of_another_app_are_ignored
    other = R2UI::App.new(R2UI.registry)
    _, command = other.init
    @app.init

    @app.update(ticks(command).first.callback.call)

    assert_nil @app.state[:fired]
  ensure
    other.stop
    @app.stop
  end

  def test_needs_a_positive_interval_and_a_block
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { every(0) { nil } } }
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { every(1) } }
  end
end
