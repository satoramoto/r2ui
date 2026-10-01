# frozen_string_literal: true

require "test_helper"

# s08-async: `async(callable) { |value, error| }` runs work off the update thread.
class AsyncTest < Minitest::Test
  def setup
    R2UI.reset!
    R2UI.dashboard do
      # The trigger: a timer whose block starts the work held in state[:work].
      every 1 do
        async(state[:work]) do |value, error|
          state[:value] = value
          state[:error] = error
          flash "done #{value}"
        end
      end

      row do
        panel :result, resource: nil do
          view { "value: #{state[:value] || "loading"}" }
        end
      end
    end
    @app = R2UI::App.new(R2UI.registry)
  end

  def teardown = @app.stop

  def text = @app.frame(40, 6).plain_lines.join("\n")

  # Fires the timer and returns the async command its block enqueued.
  def start(work)
    @app.state[:work] = work
    _, init = @app.init
    tick = init.is_a?(Bubbletea::BatchCommand) ? init.commands.first : init
    _, out = @app.update(tick.callback.call)
    commands = out.is_a?(Bubbletea::BatchCommand) ? out.commands : [out]
    commands.grep(Proc).first
  end

  # Runs a Proc command the way the runner does: on its own thread.
  def run_in_background(command) = Thread.new { command.call }

  def test_returns_a_proc_command_and_runs_nothing_on_the_update_thread
    calls = 0
    command = start(-> { calls += 1 })

    assert_kind_of Proc, command
    assert_equal 0, calls, "the callable waits for the runner"
  end

  def test_block_gets_the_value_on_the_update_thread
    worker = nil
    command = start(lambda {
      worker = Thread.current
      42
    })

    message = run_in_background(command).value
    refute_equal Thread.current, worker
    assert_kind_of Bubbletea::Message, message

    @app.update(message)

    assert_equal 42, @app.state[:value]
    assert_nil @app.state[:error]
    assert_match(/value: 42/, text)
    assert_match(/done 42/, text)
  end

  def test_block_gets_nil_and_the_exception_when_the_callable_raises
    command = start(-> { raise ArgumentError, "boom" })

    @app.update(run_in_background(command).value)

    assert_nil @app.state[:value]
    assert_kind_of ArgumentError, @app.state[:error]
    assert_equal "boom", @app.state[:error].message
  end

  def test_block_commands_run
    @app.stop
    R2UI.reset!
    R2UI.dashboard do
      every(1) { async(state[:work]) { |_value, _error| quit } }
      row { panel(:x, resource: nil) { view { "x" } } }
    end
    @app = R2UI::App.new(R2UI.registry)
    command = start(-> { :ok })

    _, out = @app.update(run_in_background(command).value)

    assert_kind_of Bubbletea::QuitCommand, out
  end

  def test_ui_keeps_drawing_while_the_work_runs
    gate = Queue.new
    command = start(-> { gate.pop })
    worker = run_in_background(command)

    assert_match(/value: loading/, text)
    @app.update(Bubbletea::WindowSizeMessage.new(width: 50, height: 7))
    assert_match(/value: loading/, @app.view)
    assert worker.alive?

    gate << "fetched"
    @app.update(worker.value)

    assert_match(/value: fetched/, text)
  end

  def test_results_after_quit_are_dropped
    command = start(-> { 7 })
    worker = run_in_background(command)

    _, out = @app.update(R2UI::Keys.message("q"))
    assert_kind_of Bubbletea::QuitCommand, out

    @app.update(worker.value)

    assert_nil @app.state[:value]
  end

  def test_results_of_another_app_are_ignored
    command = start(-> { 7 })
    other = R2UI::App.new(R2UI.registry)
    other.init

    other.update(run_in_background(command).value)

    assert_nil other.state[:value]
  ensure
    other&.stop
  end

  def test_needs_a_callable_and_a_block
    ctx = R2UI::Context.new(@app)

    assert_raises(ArgumentError) { ctx.async(42) { nil } }
    assert_raises(ArgumentError) { ctx.async(-> { 1 }) }
  end
end
