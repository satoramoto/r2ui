# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require_relative "../../../conformance/lib/vt"

class CLITasksTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI
  TIME = /\d+ms|\d+\.\ds|\d+m \d+s/

  def program(&block) = CLI::Program.build("tool") { run(&block) }

  def screen_text(out)
    vt = Conformance::VT.new(cols: 80, rows: 20)
    vt.feed(out)
    [vt.lines.map(&:rstrip).reject(&:empty?), vt]
  end

  # ---- plain (pipe) output ----

  def test_one_line_per_finished_step_and_values_in_order
    values, shell = with_shell do
      CLI.tasks do
        CLI.step("Resolving") { :resolved }
        CLI.step("Fetching") { sleep 0.01; :fetched }
        CLI.step("Linking") { nil }
      end
    end
    assert_equal [:resolved, :fetched, nil], values
    lines = shell.output.string.lines(chomp: true)
    assert_equal 3, lines.size
    assert_match(/\A✔ Resolving #{TIME}\z/o, lines[0])
    assert_match(/\A✔ Fetching #{TIME}\z/o, lines[1])
    assert_match(/\A✔ Linking #{TIME}\z/o, lines[2])
    refute_includes shell.output.string, "\e"
    assert_equal "", shell.error.string
  end

  def test_steps_run_after_the_block_in_order
    order = []
    with_shell do
      CLI.tasks do
        CLI.step("A") { order << :a }
        order << :declared
        CLI.step("B") { order << :b }
      end
    end
    assert_equal %i[declared a b], order
  end

  def test_step_alone_returns_its_value
    value, shell = with_shell { CLI.step("Building") { 42 } }
    assert_equal 42, value
    assert_match(/\A✔ Building #{TIME}\n\z/o, shell.output.string)
  end

  def test_detail_is_shown
    _, shell = with_shell do
      CLI.step("Fetching") { |s| (1..3).each { |i| s.detail = "#{i}/3" } }
    end
    assert_match(/\A✔ Fetching · 3\/3 #{TIME}\n\z/o, shell.output.string)
  end

  def test_title_can_change
    _, shell = with_shell { CLI.step("Fetching") { |s| s.title = "Fetched 3 files" } }
    assert_match(/\A✔ Fetched 3 files #{TIME}\n\z/o, shell.output.string)
  end

  def test_skip_with_and_without_reason
    ran = []
    values, shell = with_shell do
      CLI.tasks do
        CLI.step("Linking") { |s| s.skip!("nothing to link"); ran << :linking }
        CLI.step("Caching") { |s| s.skip! }
        CLI.step("Done") { ran << :done; :ok }
      end
    end
    assert_equal [nil, nil, :ok], values
    assert_equal [:done], ran
    lines = shell.output.string.lines(chomp: true)
    assert_equal "– Linking (nothing to link)", lines[0]
    assert_equal "– Caching (skipped)", lines[1]
    assert_match(/\A✔ Done #{TIME}\z/o, lines[2])
  end

  def test_failing_step_skips_the_rest_and_raises
    ran = []
    shell = nil
    error = assert_raises(RuntimeError) do
      with_shell do |s|
        shell = s
        CLI.tasks do
          CLI.step("Building") { ran << :building }
          CLI.step("Uploading") { raise "network down" }
          CLI.step("Announcing") { ran << :announcing }
        end
      end
    end
    assert_equal "network down", error.message
    assert_equal [:building], ran
    lines = shell.output.string.lines(chomp: true)
    assert_equal 3, lines.size
    assert_match(/\A✔ Building #{TIME}\z/o, lines[0])
    assert_match(/\A✖ Uploading #{TIME}\z/o, lines[1])
    assert_equal "– Announcing (skipped)", lines[2]
  end

  def test_a_failing_command_exits_1_with_the_message
    ran = []
    tool = program do
      tasks do
        step("Building") { ran << :building }
        step("Uploading") { raise "network down" }
        step("Announcing") { ran << :announcing }
      end
    end
    result = run_cli(tool)
    assert_equal 1, result.code
    assert_equal [:building], ran
    assert_equal "✖ network down\n", result.err
    lines = result.out.lines(chomp: true)
    assert_match(/\A✖ Uploading #{TIME}\z/o, lines[1])
    assert_equal "– Announcing (skipped)", lines[2]
  end

  def test_interrupt_in_a_step_exits_130
    tool = program do
      tasks do
        step("Waiting") { raise Interrupt }
        step("Never") { raise "ran" }
      end
    end
    result = run_cli(tool)
    assert_equal 130, result.code
    lines = result.out.lines(chomp: true)
    assert_match(/\A✖ Waiting #{TIME}\z/o, lines[0])
    assert_equal "– Never (skipped)", lines[1]
  end

  def test_command_values_and_helpers_inside_steps
    tool = CLI::Program.build("tool") do
      argument :app
      run do
        tasks do
          step("Deploying #{args[:app]}") { say "inside" }
        end
      end
    end
    result = run_cli(tool, "api")
    assert_equal 0, result.code
    lines = result.out.lines(chomp: true)
    assert_equal "inside", lines[0]
    assert_match(/\A✔ Deploying api #{TIME}\z/o, lines[1])
  end

  # ---- on a terminal ----

  def test_terminal_shows_pending_lines_then_the_resolved_list
    seen = nil
    values, shell = with_shell(tty: true) do |s|
      CLI.tasks do
        CLI.step("Resolving") { seen = screen_text(s.output.string).first; 1 }
        CLI.step("Fetching") { |h| h.detail = "2/2"; 2 }
        CLI.step("Linking") { |h| h.skip!("nothing to link") }
      end
    end
    assert_equal [1, 2, nil], values

    assert_equal 3, seen.size
    assert_match(/\A#{Regexp.union(CLI::Live::SPINNER)} Resolving\z/, seen[0])
    assert_equal "○ Fetching", seen[1]
    assert_equal "○ Linking", seen[2]

    lines, vt = screen_text(shell.output.string)
    assert_equal 3, lines.size
    assert_match(/\A✔ Resolving #{TIME}\z/o, lines[0])
    assert_match(/\A✔ Fetching · 2\/2 #{TIME}\z/o, lines[1])
    assert_equal "– Linking (nothing to link)", lines[2]
    assert vt.cursor_visible?
    assert_includes shell.output.string, CLI::Live::HIDE_CURSOR
  end

  def test_terminal_failure_shows_cursor_and_final_list
    shell = nil
    assert_raises(RuntimeError) do
      with_shell(tty: true) do |s|
        shell = s
        CLI.tasks do
          CLI.step("Building") { nil }
          CLI.step("Uploading") { raise "network down" }
          CLI.step("Announcing") { nil }
        end
      end
    end
    lines, vt = screen_text(shell.output.string)
    assert_equal 3, lines.size
    assert_match(/\A✔ Building #{TIME}\z/o, lines[0])
    assert_match(/\A✖ Uploading #{TIME}\z/o, lines[1])
    assert_equal "– Announcing (skipped)", lines[2]
    assert vt.cursor_visible?
    assert shell.output.string.end_with?(CLI::Live::SHOW_CURSOR)
  end

  def test_terminal_say_inside_a_step_lands_above_the_list
    _, shell = with_shell(tty: true) do
      CLI.tasks do
        CLI.step("Building") { CLI.say "compiled 3 files" }
        CLI.step("Uploading") { CLI.say "uploaded" }
      end
    end
    lines, = screen_text(shell.output.string)
    assert_equal "compiled 3 files", lines[0]
    assert_equal "uploaded", lines[1]
    assert_match(/\A✔ Building #{TIME}\z/o, lines[2])
    assert_match(/\A✔ Uploading #{TIME}\z/o, lines[3])
    assert_equal 4, lines.size
  end

  def test_terminal_command_failure_exit_code
    tool = program do
      tasks { step("Uploading") { raise "network down" } }
    end
    result = run_cli(tool, tty: true)
    assert_equal 1, result.code
    assert_equal "✖ network down\n", result.err
    lines, vt = screen_text(result.out)
    assert_match(/\A✖ Uploading #{TIME}\z/o, lines[0])
    assert vt.cursor_visible?
  end

  # ---- misuse ----

  def test_nested_tasks_raise
    with_shell do
      assert_raises(CLI::Error) { CLI.tasks { CLI.tasks { nil } } }
    end
  end

  def test_step_inside_a_running_step_raises
    with_shell do
      assert_raises(CLI::Error) do
        CLI.tasks { CLI.step("Outer") { CLI.step("Inner") { nil } } }
      end
    end
  end

  def test_tasks_inside_a_running_step_raises
    with_shell do
      assert_raises(CLI::Error) { CLI.step("Outer") { CLI.tasks { CLI.step("Inner") { nil } } } }
    end
  end

  def test_lists_can_run_again_after_one_failed
    with_shell do
      assert_raises(CLI::Error) { CLI.tasks { CLI.tasks { nil } } }
      assert_equal 1, CLI.step("Again") { 1 }
    end
  end

  def test_tasks_and_step_need_blocks
    with_shell do
      assert_raises(ArgumentError) { CLI.tasks }
      assert_raises(ArgumentError) { CLI.tasks { CLI.step("No block") } }
    end
  end

  # ---- durations ----

  def test_duration
    assert_equal "120ms", CLI::Ext::Tasks.duration(0.12)
    assert_equal "0ms", CLI::Ext::Tasks.duration(0)
    assert_equal "3.5s", CLI::Ext::Tasks.duration(3.456)
    assert_equal "1m 15s", CLI::Ext::Tasks.duration(75)
    # Rounding happens before the unit is picked.
    assert_equal "1.0s", CLI::Ext::Tasks.duration(0.9996)
    assert_equal "1m 0s", CLI::Ext::Tasks.duration(59.97)
    assert_equal "2m 0s", CLI::Ext::Tasks.duration(119.6)
  end
end
