# frozen_string_literal: true

require "minitest/autorun"
require "timeout"
require "r2ui/cli/testing"
require_relative "../../../conformance/lib/vt"

class CLIParallelTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI
  TIME = /\d+ms|\d+\.\ds|\d+m \d+s/
  SPIN = Regexp.union(R2UI::CLI::Live::SPINNER)

  def program(&block) = CLI::Program.build("tool") { run(&block) }

  def screen_text(out, rows: 30)
    vt = Conformance::VT.new(cols: 80, rows:)
    vt.feed(out)
    [vt.lines.map(&:rstrip).reject(&:empty?), vt]
  end

  # Waits for a hand-off between jobs; fails the test instead of hanging.
  def wait_for(queue) = queue.pop(timeout: 5) || flunk("timed out waiting for another job")

  # ---- plain (pipe) output ----

  def test_returns_values_by_job_name_and_one_line_per_job
    values, shell = with_shell do
      CLI.parallel(max: 4) do
        CLI.job("api") { :api_built }
        CLI.job("web") { :web_built }
      end
    end
    assert_equal({ "api" => :api_built, "web" => :web_built }, values)
    assert_equal %w[api web], values.keys
    lines = shell.output.string.lines(chomp: true)
    assert_equal 2, lines.size
    lines.each { |line| assert_match(/\A✔ (api|web) #{TIME}\z/o, line) }
    assert_equal %w[api web], lines.map { |l| l.split[1] }.sort
    refute_includes shell.output.string, "\e"
    assert_equal "", shell.error.string
  end

  def test_jobs_run_at_the_same_time
    a_started = Queue.new
    b_started = Queue.new
    values, = with_shell do
      CLI.parallel(max: 2) do
        CLI.job("a") { a_started << true; wait_for(b_started); 1 }
        CLI.job("b") { b_started << true; wait_for(a_started); 2 }
      end
    end
    assert_equal({ "a" => 1, "b" => 2 }, values)
  end

  def test_no_more_than_max_jobs_run_at_once
    lock = Mutex.new
    running = 0
    peak = 0
    with_shell do
      CLI.parallel(max: 2) do
        6.times do |i|
          CLI.job("job#{i}") do
            lock.synchronize { peak = [peak, running += 1].max }
            sleep 0.02
            lock.synchronize { running -= 1 }
          end
        end
      end
    end
    assert_operator peak, :<=, 2
  end

  def test_max_one_runs_in_declaration_order
    order = []
    with_shell do
      CLI.parallel(max: 1) do
        %w[a b c].each { |name| CLI.job(name) { order << name } }
      end
    end
    assert_equal %w[a b c], order
  end

  def test_lines_print_as_jobs_end
    fast_done = Queue.new
    _, shell = with_shell do
      CLI.parallel(max: 2) do
        CLI.job("slow") { wait_for(fast_done) }
        CLI.job("fast") { fast_done << true }
      end
    end
    lines = shell.output.string.lines(chomp: true)
    assert_match(/\A✔ fast #{TIME}\z/o, lines[0])
    assert_match(/\A✔ slow #{TIME}\z/o, lines[1])
  end

  def test_detail_and_say_inside_a_job
    _, shell = with_shell do
      CLI.parallel do
        CLI.job("api") { |j| j.detail = "3 files"; CLI.say("compiled") }
      end
    end
    lines = shell.output.string.lines(chomp: true)
    assert_equal "compiled", lines[0]
    assert_match(/\A✔ api · 3 files #{TIME}\z/o, lines[1])
  end

  def test_a_failing_job_does_not_stop_the_others_and_raises_after_all_end
    failed = Queue.new
    shell = nil
    error = assert_raises(CLI::Error) do
      with_shell do |s|
        shell = s
        CLI.parallel(max: 2) do
          CLI.job("api") { failed << true; raise "network down" }
          CLI.job("web") { wait_for(failed); sleep 0.05; :web }
          CLI.job("docs") { :docs }
        end
      end
    end
    assert_includes error.message, "api"
    refute_includes error.message, "web"
    assert_instance_of RuntimeError, error.cause
    assert_equal "network down", error.cause.message
    lines = shell.output.string.lines(chomp: true)
    assert_equal 3, lines.size
    assert_equal 1, lines.grep(/\A✖ api · network down #{TIME}\z/o).size
    assert_equal 1, lines.grep(/\A✔ web #{TIME}\z/o).size
    assert_equal 1, lines.grep(/\A✔ docs #{TIME}\z/o).size
    assert_match(/\A✔ web/, lines.last, "web ran to the end after api failed")
  end

  def test_several_failures_are_named_and_the_first_is_the_cause
    first_failed = Queue.new
    error = assert_raises(CLI::Error) do
      with_shell do
        CLI.parallel(max: 3) do
          CLI.job("web") { wait_for(first_failed); raise ArgumentError, "second" }
          CLI.job("ok") { 1 }
          CLI.job("api") do
            first_failed << true
            raise "first"
          end
        end
      end
    end
    assert_match(/web.*api/, error.message, "failed jobs are named in declaration order")
    assert_equal "first", error.cause.message
  end

  def test_a_failing_command_exits_1_with_the_failed_jobs_named
    tool = program do
      parallel do
        job("api") { :ok }
        job("web") { raise "webpack exploded" }
      end
    end
    result = run_cli(tool)
    assert_equal 1, result.code
    assert_match(/\A✖ .*web/, result.err)
    refute_match(/\bapi\b/, result.err)
    assert_match(/^✖ web · webpack exploded #{TIME}$/o, result.out)
    assert_match(/^✔ api #{TIME}$/o, result.out)
  end

  def test_command_values_are_visible_inside_jobs
    tool = CLI::Program.build("tool") do
      argument :app
      run do
        values = parallel { job("build #{args[:app]}") { args[:app].upcase } }
        say values.inspect
      end
    end
    result = run_cli(tool, "api")
    assert_equal 0, result.code
    lines = result.out.lines(chomp: true)
    assert_match(/\A✔ build api #{TIME}\z/o, lines[0])
    assert_equal({ "build api" => "API" }.inspect, lines[1])
  end

  def test_interrupt_in_a_job_cancels_the_rest_and_exits_130
    started = Queue.new
    tool = program do
      parallel(max: 2) do
        job("waiting") { started << true; sleep }
        job("boom") { started.pop(timeout: 5); raise Interrupt }
        job("queued") { raise "ran" }
      end
    end
    result = Timeout.timeout(5) { run_cli(tool) }
    assert_equal 130, result.code
    lines = result.out.lines(chomp: true)
    assert_includes lines, "– waiting (cancelled)"
    assert_includes lines, "– queued (cancelled)"
    refute(lines.any? { |l| l.include?("ran") })
  end

  def test_empty_parallel_returns_an_empty_hash
    values, shell = with_shell { CLI.parallel { nil } }
    assert_equal({}, values)
    assert_equal "", shell.output.string
  end

  # ---- on a terminal ----

  def test_terminal_redraws_all_jobs_together
    seen = nil
    release = Queue.new
    values, shell = with_shell(tty: true) do |s|
      CLI.parallel(max: 2) do
        CLI.job("api") { |j| j.detail = "bundling"; wait_for(release); 1 }
        CLI.job("web") do
          sleep 0.01 until s.output.string.include?("bundling")
          seen = screen_text(s.output.string).first
          release << true
          2
        end
        CLI.job("docs") { 3 }
      end
    end
    assert_equal({ "api" => 1, "web" => 2, "docs" => 3 }, values)

    assert_equal 3, seen.size
    assert_match(/\A#{SPIN} api · bundling\z/o, seen[0])
    assert_match(/\A#{SPIN} web\z/o, seen[1])
    assert_equal "○ docs", seen[2]

    lines, vt = screen_text(shell.output.string)
    assert_equal 3, lines.size
    assert_match(/\A✔ api · bundling #{TIME}\z/o, lines[0])
    assert_match(/\A✔ web #{TIME}\z/o, lines[1])
    assert_match(/\A✔ docs #{TIME}\z/o, lines[2])
    assert vt.cursor_visible?
    assert_includes shell.output.string, CLI::Live::HIDE_CURSOR
  end

  def test_terminal_failure_keeps_the_final_lines_and_shows_the_cursor
    shell = nil
    assert_raises(CLI::Error) do
      with_shell(tty: true) do |s|
        shell = s
        CLI.parallel do
          CLI.job("api") { nil }
          CLI.job("web") { raise "network down" }
        end
      end
    end
    lines, vt = screen_text(shell.output.string)
    assert_equal 2, lines.size
    assert_match(/\A✔ api #{TIME}\z/o, lines[0])
    assert_match(/\A✖ web · network down #{TIME}\z/o, lines[1])
    assert vt.cursor_visible?
    assert shell.output.string.end_with?(CLI::Live::SHOW_CURSOR)
  end

  def test_terminal_say_inside_a_job_lands_above
    _, shell = with_shell(tty: true) do
      CLI.parallel { CLI.job("api") { CLI.say("compiled 3 files") } }
    end
    lines, = screen_text(shell.output.string)
    assert_equal "compiled 3 files", lines[0]
    assert_match(/\A✔ api #{TIME}\z/o, lines[1])
    assert_equal 2, lines.size
  end

  def test_terminal_with_more_jobs_than_rows_keeps_every_result
    _, shell = with_shell(tty: true, env: { "LINES" => "6" }) do
      CLI.parallel(max: 2) do
        12.times { |i| CLI.job(format("pkg%02d", i)) { sleep 0.005 } }
      end
    end
    lines, vt = screen_text(shell.output.string, rows: 40)
    assert_equal 12, lines.size, lines.inspect
    lines.each { |line| assert_match(/\A✔ pkg\d\d #{TIME}\z/o, line) }
    assert_equal (0...12).map { |i| format("pkg%02d", i) }, lines.map { |l| l.split[1] }.sort
    assert vt.cursor_visible?
  end

  def test_terminal_command_failure_exit_code
    tool = program { parallel { job("web") { raise "network down" } } }
    result = run_cli(tool, tty: true)
    assert_equal 1, result.code
    assert_match(/\A✖ .*web/, result.err)
    lines, vt = screen_text(result.out)
    assert_match(/\A✖ web · network down #{TIME}\z/o, lines[0])
    assert vt.cursor_visible?
  end

  # ---- misuse ----

  def test_job_outside_parallel_raises
    with_shell { assert_raises(CLI::Error) { CLI.job("api") { nil } } }
  end

  def test_parallel_and_job_need_blocks
    with_shell do
      assert_raises(ArgumentError) { CLI.parallel }
      assert_raises(ArgumentError) { CLI.parallel { CLI.job("api") } }
    end
  end

  def test_job_names_are_unique
    with_shell do
      assert_raises(ArgumentError) { CLI.parallel { CLI.job("api") { 1 }; CLI.job("api") { 2 } } }
    end
  end

  def test_max_must_be_a_positive_integer
    with_shell do
      assert_raises(ArgumentError) { CLI.parallel(max: 0) { nil } }
      assert_raises(ArgumentError) { CLI.parallel(max: "2") { nil } }
    end
  end

  def test_parallel_inside_a_job_raises
    error = assert_raises(CLI::Error) do
      with_shell { CLI.parallel { CLI.job("outer") { CLI.parallel { CLI.job("inner") { 1 } } } } }
    end
    assert_kind_of CLI::Error, error.cause
  end

  def test_parallel_can_run_again_after_a_failure
    with_shell do
      assert_raises(CLI::Error) { CLI.parallel { CLI.job("a") { raise "x" } } }
      assert_equal({ "b" => 1 }, CLI.parallel { CLI.job("b") { 1 } })
    end
  end
end
