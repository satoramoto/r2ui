# frozen_string_literal: true

require "test_helper"
require_relative "../compat/bubbletea/pty_helper"

# s09-exec: `execute(*argv) { |status| }` hands the terminal to a foreground program, takes it back,
# then runs the block with the Process::Status.
#
# The definitions trigger `execute` from an `every` timer (the key keywords belong to other
# stories), guarded so it runs once.
class ExecTest < Minitest::Test
  def setup = R2UI.reset!

  # An r2ui program that runs `argv` once, shows "status: N" afterwards, and quits on "q".
  def program(argv)
    <<~RUBY
      require "r2ui"
      R2UI.dashboard do
        every(0.05) do
          next if state[:started]

          state[:started] = true
          execute(*#{argv.inspect}) { |status| state[:status] = status.exitstatus }
        end
        row(height: 3) do
          panel(:out, resource: nil) { view { "status: \#{state.fetch(:status, "waiting")}" } }
        end
      end
      R2UI.run
    RUBY
  end

  def run_program(code)
    PtyHelper.run(code, load_path: [PtyHelper::LIB], width: 60, height: 12) do |driver|
      driver.wait_for("waiting")
      yield driver
      driver.type("q")
    end
  end

  def test_execute_returns_a_command_instead_of_running_the_program_inline
    R2UI.dashboard do
      every(1) { execute("true") { |_status| state[:ran] = true } }
    end
    app = R2UI::App.new(R2UI.registry)
    _, command = app.init
    tick = (command.is_a?(Bubbletea::BatchCommand) ? command.commands : [command]).first

    _, out = app.update(tick.callback.call)

    refute_nil out
    assert_nil app.state[:ran], "the block waits for the program to finish"
  ensure
    app.stop
  end

  def test_the_child_output_reaches_the_terminal_and_the_app_is_drawn_again_after_it
    run = run_program(program(["sh", "-c", "echo CHILD_SAYS_HI"])) { |d| d.wait_for("status: 0") }

    assert run.status.success?, run.output.inspect
    out = run.output.b
    child = out.index("CHILD_SAYS_HI".b)
    refute_nil child, "child output missing: #{out.inspect}"
    assert out.index("status: 0".b, child), "app not redrawn after the child ran"
  end

  def test_the_block_gets_the_exit_status_of_the_program
    run = run_program(program(["sh", "-c", "exit 3"])) { |d| d.wait_for("status: 3") }

    assert run.status.success?, run.output.inspect
  end

  def test_the_alt_screen_is_left_while_the_program_runs_and_entered_again_after
    run = run_program(program(["sh", "-c", "echo CHILD_SAYS_HI"])) { |d| d.wait_for("status: 0") }
    out = run.output.b
    child = out.index("CHILD_SAYS_HI".b)

    refute_nil child
    assert out.rindex("\e[?1049l".b, child), "alt screen not left before the child ran"
    assert out.index("\e[?1049h".b, child), "alt screen not re-entered after the child ran"
  end

  def test_the_terminal_is_cooked_and_the_cursor_shown_while_the_program_runs
    # `stty -a` reports the tty the child inherits: raw mode would show -icanon / -echo.
    run = run_program(program(["sh", "-c", "stty -a | tr ' ' '\\n' | grep -x -e icanon -e echo | sort | tr '\\n' ,"])) do |d|
      d.wait_for("status: 0")
    end

    assert_includes run.output.b, "echo,icanon,".b, run.output.inspect
  end

  def test_the_terminal_is_restored_when_the_app_quits_after_running_a_program
    run = run_program(program(["true"])) { |d| d.wait_for("status: 0") }

    assert run.status.success?, run.output.inspect
    assert run.tty_restored, "terminal left in raw mode"
    assert run.output.end_with?("\e[?1049l\e[?25h"), run.output[-40..].inspect
  end
end
