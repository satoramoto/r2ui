# frozen_string_literal: true

require "test_helper"

# s06-after: `after(seconds) { }` runs its block once, on the update thread, after `seconds`.
class AfterTest < Minitest::Test
  def setup
    R2UI.reset!
    @extensions = []
    # A key binding (s03's on_key isn't required here): pressing "a" schedules a one-shot.
    extension(:test_after_key) do
      on(->(msg) { msg.is_a?(Bubbletea::KeyMessage) && R2UI::Keys.name(msg) == "a" }) do
        state[:returned] = after(2) do
          state[:fired] = state[:fired].to_i + 1
          flash "fired #{state[:fired]}"
          quit
        end
      end
    end
    R2UI.dashboard do
      every(10) { after(Rational(1, 4)) { state[:from_timer] = true } }

      row do
        panel :p, resource: nil do
          view { "fired: #{state[:fired].to_i}" }
        end
      end
    end
    @app = R2UI::App.new(R2UI.registry)
    _, @timer = @app.init
  end

  def teardown
    @app.stop
    @extensions.each { |name| R2UI::Extensions.remove(name) }
  end

  def extension(name, &)
    @extensions << name
    R2UI.extension(name, &)
  end

  def commands(command) = command.is_a?(Bubbletea::BatchCommand) ? command.commands : [command]

  def test_returns_a_tick_command_for_the_delay
    command, = @app.press("a")

    assert_kind_of Bubbletea::TickCommand, command
    assert_equal 2.0, command.duration
    assert_same command, @app.state[:returned]
    assert_nil @app.state[:fired]
  end

  def test_runs_the_block_once_with_its_commands
    tick, = @app.press("a")

    _, out = @app.update(tick.callback.call)

    assert_equal 1, @app.state[:fired]
    assert_kind_of Bubbletea::QuitCommand, out
    assert_match(/fired 1/, @app.frame(40, 5).plain_lines.join("\n"))
    assert_match(/fired: 1/, @app.view)
  end

  def test_a_later_after_does_not_cancel_an_earlier_one
    first, = @app.press("a")
    second, = @app.press("a")

    @app.update(first.callback.call)
    @app.update(second.callback.call)

    assert_equal 2, @app.state[:fired]
  end

  def test_usable_from_a_timer_block
    _, out = @app.update(@timer.callback.call)
    once = commands(out).find { |c| c.duration == 0.25 }

    @app.update(once.callback.call)

    assert @app.state[:from_timer]
  end

  def test_one_shots_of_another_app_are_ignored
    other = R2UI::App.new(R2UI.registry)
    other.init
    tick, = other.press("a")

    @app.update(tick.callback.call)

    assert_nil @app.state[:fired]
  ensure
    other&.stop
  end

  def test_needs_a_block_and_a_non_negative_delay
    context = R2UI::Context.new(@app)

    assert_raises(ArgumentError) { context.after(-1) { nil } }
    assert_raises(ArgumentError) { context.after(1) }
    assert_equal 0.0, context.after(0) { nil }.duration
  end
end
