# frozen_string_literal: true

require "test_helper"

# s29-timer: `countdown :name, seconds, on_timeout: -> { }` hosts a Bubbles::Timer in a panel.
class CountdownTest < Minitest::Test
  def setup
    R2UI.reset!
    R2UI.dashboard do
      row do
        panel :clock, resource: nil do
          countdown :deadline, 3, on_timeout: -> { state[:timeouts] = state[:timeouts].to_i + 1 }
        end
      end
    end
    @app = R2UI::App.new(R2UI.registry)
  end

  def teardown = @app&.stop

  def text(width = 40, height = 6) = @app.frame(width, height).plain_lines.join("\n")

  def commands(command) = command.is_a?(Bubbletea::BatchCommand) ? command.commands : [command]

  # Delivers the next tick the app asked for, as the runner would after the interval.
  def run_tick(command)
    tick = commands(command).find { |c| c.is_a?(Bubbletea::TickCommand) }
    @app.update(tick.callback.call).last
  end

  def test_hosts_a_bubbles_timer_named_by_the_item
    @app.init

    assert_kind_of Bubbles::Timer, @app.component(:deadline)
    assert_equal 3.0, @app.component(:deadline).timeout
  end

  def test_init_starts_the_timer_with_a_one_second_tick
    _, command = @app.init
    tick = commands(command).find { |c| c.is_a?(Bubbletea::TickCommand) }

    refute_nil tick, "init should return the timer's first tick"
    assert_equal 1.0, tick.duration
  end

  def test_shows_the_time_left
    _, command = @app.init

    assert_match(/│3s/, text)

    run_tick(command)

    assert_match(/│2s/, text)
  end

  def test_does_not_call_on_timeout_before_the_end
    _, command = @app.init
    command = run_tick(command)
    run_tick(command)

    assert_nil @app.state[:timeouts]
    assert_match(/│1s/, text)
  end

  def test_calls_on_timeout_when_the_timer_ends
    _, command = @app.init
    2.times { command = run_tick(command) }
    run_tick(command)

    @app.update(Bubbles::Timer::TimeoutMessage.new(id: @app.component(:deadline).id))

    assert_equal 1, @app.state[:timeouts]
    assert_match(/│0s/, text)
  end

  def test_calls_on_timeout_once
    @app.init
    timeout = Bubbles::Timer::TimeoutMessage.new(id: @app.component(:deadline).id)

    @app.update(timeout)
    @app.update(timeout)

    assert_equal 1, @app.state[:timeouts]
  end

  def test_ignores_the_timeout_of_another_timer
    @app.init

    @app.update(Bubbles::Timer::TimeoutMessage.new(id: Bubbles::Timer.new(1).id))

    assert_nil @app.state[:timeouts]
  end

  def test_on_timeout_may_return_a_command
    R2UI.reset!
    R2UI.dashboard do
      row { panel(:clock, resource: nil) { countdown :deadline, 1, on_timeout: -> { quit } } }
    end
    app = R2UI::App.new(R2UI.registry)
    app.init

    _, command = app.update(Bubbles::Timer::TimeoutMessage.new(id: app.component(:deadline).id))

    assert_includes commands(command).map(&:class), Bubbletea::QuitCommand
  ensure
    app&.stop
  end
end
