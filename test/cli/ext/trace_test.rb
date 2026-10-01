# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require_relative "../../../conformance/lib/vt"

class CLITraceTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI

  def failing(error = RuntimeError.new("boom"), trace: true)
    CLI::Program.build("tool") do
      trace_option if trace
      run { raise error }
      command(:deploy) { run { raise error } }
      command(:stop) { run { abort!("not running") } }
    end
  end

  def raise_boom = raise("boom")

  # A program whose error has a real backtrace through a named method.
  def deep
    test = self
    CLI::Program.build("tool") do
      trace_option
      run { test.raise_boom }
    end
  end

  def screen_text(out)
    vt = Conformance::VT.new(cols: 200, rows: 60)
    vt.feed(out.gsub("\n", "\r\n"))
    vt.lines.map(&:rstrip).reject(&:empty?)
  end

  # ---- with --trace ----

  def test_trace_prints_message_class_and_full_backtrace
    result = run_cli(deep, "--trace")
    assert_equal 1, result.code
    assert_equal "", result.out
    lines = result.err.lines(chomp: true)
    assert_equal "✖ boom", lines[0]
    assert_equal "RuntimeError", lines[1]
    trace = lines[2..]
    assert_operator trace.size, :>, 3
    assert(trace.all? { |l| l.start_with?("  ") }, trace.inspect)
    assert_match(/trace_test\.rb:\d+:in .*raise_boom/, trace[0])
    refute_includes result.err, "\e"
  end

  def test_backtrace_is_the_whole_backtrace
    error = nil
    program = CLI::Program.build("tool") do
      trace_option
      run do
        raise "boom"
      rescue StandardError => e
        error = e
        raise
      end
    end
    result = run_cli(program, "--trace")
    trace = result.err.lines(chomp: true)[2..].map(&:strip)
    assert_equal error.backtrace, trace
  end

  def test_trace_works_on_a_subcommand
    result = run_cli(failing, "deploy", "--trace")
    assert_equal 1, result.code
    lines = result.err.lines(chomp: true)
    assert_equal ["✖ boom", "RuntimeError"], lines[0, 2]
    assert_operator lines.size, :>, 2
  end

  def test_trace_shows_the_cause
    program = CLI::Program.build("tool") do
      trace_option
      run do
        {}.fetch(:token)
      rescue KeyError
        raise ArgumentError, "no token"
      end
    end
    result = run_cli(program, "--trace")
    assert_equal 1, result.code
    lines = result.err.lines(chomp: true)
    assert_equal ["✖ no token", "ArgumentError"], lines[0, 2]
    assert_includes lines, "Caused by KeyError: key not found: :token"
  end

  def test_trace_is_muted_on_a_terminal
    result = begin
      R2UI::Compat::Gloss::Renderer.color_profile = :ansi
      run_cli(deep, "--trace", tty: true, color: true)
    ensure
      R2UI::Compat::Gloss::Renderer.color_profile = nil
    end
    assert_equal 1, result.code
    raw = result.err.lines(chomp: true)
    assert_includes raw[1], "\e[", "class line is styled"
    assert(raw[2..].all? { |l| l.include?("\e[") }, "every backtrace line is styled")
    lines = screen_text(result.err)
    assert_equal "✖ boom", lines[0]
    assert_equal "RuntimeError", lines[1]
    assert_match(/\A  .*trace_test\.rb:\d+/, lines[2])
  end

  def test_expected_errors_are_unchanged_with_trace
    result = run_cli(failing, "stop", "--trace")
    assert_equal 1, result.code
    assert_equal "✖ not running\n", result.err
  end

  def test_usage_errors_are_unchanged_with_trace
    result = run_cli(failing, "deploy", "--trace", "--nope")
    assert_equal 2, result.code
    assert_equal "✖ unknown option '--nope'", result.err.lines(chomp: true).first
    refute_includes result.err, "RuntimeError"
  end

  def test_trace_does_not_print_twice_with_r2ui_trace
    result = run_cli(deep, "--trace", env: { "R2UI_TRACE" => "1" })
    assert_equal 1, result.err.scan("RuntimeError").size
    assert_equal 1, result.err.scan("✖ boom").size
  end

  # ---- without --trace ----

  def test_without_trace_only_the_message
    result = run_cli(failing)
    assert_equal 1, result.code
    assert_equal "✖ boom\n", result.err
  end

  def test_without_trace_option_the_flag_does_not_exist
    result = run_cli(failing(trace: false), "--trace")
    assert_equal 2, result.code
    refute_includes result.err, "RuntimeError"
  end

  def test_succeeding_command_is_unaffected
    program = CLI::Program.build("tool") do
      trace_option
      run { say "ok" }
    end
    result = run_cli(program, "--trace")
    assert_equal 0, result.code
    assert_equal "ok\n", result.out
    assert_equal "", result.err
  end

  # ---- help ----

  def test_help_lists_trace_on_every_command
    assert_includes run_cli(failing, "--help").out, "--trace"
    assert_includes run_cli(failing, "deploy", "--help").out, "--trace"
    refute_includes run_cli(failing(trace: false), "--help").out, "--trace"
  end
end
