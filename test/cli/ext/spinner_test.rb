# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require_relative "../../../conformance/lib/vt"

class CLISpinnerTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI
  TIME = /\d+ms|\d+\.\ds|\d+m \d+s/
  SPIN = Regexp.union(CLI::Live::SPINNER)

  def program(&block) = CLI::Program.build("tool") { run(&block) }

  def screen_text(out)
    vt = Conformance::VT.new(cols: 80, rows: 20)
    vt.feed(out)
    [vt.lines.map(&:rstrip).reject(&:empty?), vt]
  end

  # ---- off a terminal ----

  def test_pipe_prints_only_the_resolved_line_and_returns_the_value
    value, shell = with_shell do
      CLI.spin("Installing", done: "Installed") { |s| s.text = "Installing 3/3"; sleep 0.01; :ok }
    end
    assert_equal :ok, value
    assert_match(/\A✔ Installed #{TIME}\n\z/o, shell.output.string)
    assert_equal "", shell.error.string
  end

  def test_done_defaults_to_the_title
    _, shell = with_shell { CLI.spin("Installing") { |s| s.text = "half way" } }
    assert_match(/\A✔ Installing #{TIME}\n\z/o, shell.output.string)
  end

  def test_done_lambda_gets_the_blocks_value
    value, shell = with_shell do
      CLI.spin("Installing", done: ->(n) { "Installed #{n} packages" }) { 42 }
    end
    assert_equal 42, value
    assert_match(/\A✔ Installed 42 packages #{TIME}\n\z/o, shell.output.string)
  end

  def test_exception_resolves_to_a_cross_and_propagates
    shell = nil
    error = assert_raises(RuntimeError) do
      with_shell do |s|
        shell = s
        CLI.spin("Installing", done: "Installed") { |sp| sp.text = "fetching"; raise "registry down" }
      end
    end
    assert_equal "registry down", error.message
    assert_equal "✖ Installing\n", shell.output.string
  end

  def test_clear_prints_nothing_on_success_but_still_shows_failure
    value, shell = with_shell { CLI.spin("Checking", clear: true) { :fine } }
    assert_equal :fine, value
    assert_equal "", shell.output.string

    shell = nil
    assert_raises(RuntimeError) do
      with_shell { |s| shell = s; CLI.spin("Checking", clear: true) { raise "bad" } }
    end
    assert_equal "✖ Checking\n", shell.output.string
  end

  def test_say_inside_prints_before_the_resolved_line
    _, shell = with_shell { CLI.spin("Building") { CLI.say "compiled 3 files" } }
    lines = shell.output.string.lines(chomp: true)
    assert_equal "compiled 3 files", lines[0]
    assert_match(/\A✔ Building #{TIME}\z/o, lines[1])
  end

  def test_in_a_command_failure_exits_1_and_interrupt_130
    result = run_cli(program { spin("Installing") { raise "registry down" } })
    assert_equal 1, result.code
    assert_equal "✖ Installing\n", result.out
    assert_equal "✖ registry down\n", result.err

    result = run_cli(program { spin("Waiting") { raise Interrupt } })
    assert_equal 130, result.code
    assert_equal "✖ Waiting\n", result.out
  end

  def test_needs_a_block
    with_shell { assert_raises(ArgumentError) { CLI.spin("Nothing") } }
  end

  # ---- on a terminal ----

  def test_terminal_shows_spinner_and_text_then_the_resolved_line
    seen = []
    value, shell = with_shell(tty: true) do |s|
      CLI.spin("Installing", done: "Installed") do |sp|
        seen << screen_text(s.output.string).first
        sp.text = "Installing react"
        seen << screen_text(s.output.string).first
        :ok
      end
    end
    assert_equal :ok, value
    assert_equal 1, seen[0].size
    assert_match(/\A#{SPIN} Installing\z/, seen[0][0])
    assert_match(/\A#{SPIN} Installing react\z/, seen[1][0])

    lines, vt = screen_text(shell.output.string)
    assert_equal 1, lines.size
    assert_match(/\A✔ Installed #{TIME}\z/o, lines[0])
    assert vt.cursor_visible?
    assert_includes shell.output.string, CLI::Live::HIDE_CURSOR
  end

  def test_terminal_failure_leaves_a_cross_and_restores_the_cursor
    shell = nil
    assert_raises(RuntimeError) do
      with_shell(tty: true) { |s| shell = s; CLI.spin("Installing") { raise "registry down" } }
    end
    lines, vt = screen_text(shell.output.string)
    assert_equal ["✖ Installing"], lines
    assert vt.cursor_visible?
    assert shell.output.string.end_with?(CLI::Live::SHOW_CURSOR)
  end

  def test_terminal_clear_erases_the_line_on_success
    value, shell = with_shell(tty: true) { CLI.spin("Checking", clear: true) { 7 } }
    assert_equal 7, value
    lines, vt = screen_text(shell.output.string)
    assert_equal [], lines
    assert vt.cursor_visible?
  end

  def test_terminal_say_inside_lands_above_the_spinner
    _, shell = with_shell(tty: true) { CLI.spin("Building") { CLI.say "compiled 3 files" } }
    lines, = screen_text(shell.output.string)
    assert_equal "compiled 3 files", lines[0]
    assert_match(/\A✔ Building #{TIME}\z/o, lines[1])
    assert_equal 2, lines.size
  end

  def test_terminal_spin_inside_another_live_region_prints_above_it
    _, shell = with_shell(tty: true) do
      CLI.spin("Outer") { CLI.spin("Inner") { nil } }
    end
    lines, vt = screen_text(shell.output.string)
    assert_match(/\A✔ Inner #{TIME}\z/o, lines[0])
    assert_match(/\A✔ Outer #{TIME}\z/o, lines[1])
    assert_equal 2, lines.size
    assert vt.cursor_visible?
  end

  def test_terminal_colours_only_when_colour_is_on
    _, plain = with_shell(tty: true) { CLI.spin("Building") { nil } }
    refute_match(/\e\[[0-9;]*m/, plain.output.string)
  end
end
