# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require_relative "../../../conformance/lib/vt"

class CLIProgressTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI
  TIME = /\d+ms|\d+\.\ds|\d+m \d+s/
  BAR = /[━╸─]+/

  def program(&block) = CLI::Program.build("tool") { run(&block) }

  def screen_text(out, cols: 80)
    vt = Conformance::VT.new(cols:, rows: 20)
    vt.feed(out)
    [vt.lines.map(&:rstrip).reject(&:empty?), vt]
  end

  # ---- plain (pipe) output ----

  def test_pipe_prints_quarter_milestones_then_the_resolved_line
    value, shell = with_shell do
      CLI.progress(total: 100, title: "Processing") { |bar| 100.times { bar.advance }; :ok }
    end
    assert_equal :ok, value
    lines = shell.output.string.lines(chomp: true)
    assert_equal ["Processing 25%", "Processing 50%", "Processing 75%"], lines[0, 3]
    assert_match(/\A✔ Processing 100 #{TIME}\z/o, lines[3])
    assert_equal 4, lines.size
    refute_includes shell.output.string, "\e"
    assert_equal "", shell.error.string
  end

  def test_pipe_bytes_resolve_to_a_human_size
    _, shell = with_shell do
      CLI.progress(total: 10_000_000, title: "Downloading", unit: :bytes) do |bar|
        10.times { bar.advance(1_000_000) }
      end
    end
    lines = shell.output.string.lines(chomp: true)
    assert_equal ["Downloading 25%", "Downloading 50%", "Downloading 75%"], lines[0, 3]
    assert_match(/\A✔ Downloading 10 MB #{TIME}\z/o, lines[3])
  end

  def test_a_jump_prints_each_milestone_it_passes_once
    _, shell = with_shell do
      CLI.progress(total: 200, title: "Copying", unit: "files") do |bar|
        bar.current = 160
        bar.current = 170
        bar.current = 200
      end
    end
    lines = shell.output.string.lines(chomp: true)
    assert_equal ["Copying 25%", "Copying 50%", "Copying 75%"], lines[0, 3]
    assert_match(/\A✔ Copying 200 files #{TIME}\z/o, lines[3])
    assert_equal 4, lines.size
  end

  def test_total_can_be_set_later
    _, shell = with_shell do
      CLI.progress(title: "Scanning") do |bar|
        bar.advance(10)
        assert_nil bar.total
        bar.total = 40
        bar.advance(10)
        assert_equal 20, bar.current
      end
    end
    lines = shell.output.string.lines(chomp: true)
    assert_equal ["Scanning 25%", "Scanning 50%"], lines[0, 2]
    assert_match(/\A✔ Scanning 20 #{TIME}\z/o, lines[2])
  end

  def test_indeterminate_off_a_terminal_prints_only_the_resolved_line
    _, shell = with_shell do
      CLI.progress(title: "Downloading", unit: :bytes) { |bar| bar.advance(3_000_000) }
    end
    assert_match(/\A✔ Downloading 3 MB #{TIME}\n\z/o, shell.output.string)
  end

  def test_failure_shows_a_cross_and_re_raises
    shell = nil
    error = assert_raises(RuntimeError) do
      with_shell do |s|
        shell = s
        CLI.progress(total: 100, title: "Uploading") do |bar|
          bar.advance(30)
          raise "network down"
        end
      end
    end
    assert_equal "network down", error.message
    lines = shell.output.string.lines(chomp: true)
    assert_equal "Uploading 25%", lines[0]
    assert_match(/\A✖ Uploading 30\/100 #{TIME}\z/o, lines[1])
    assert_equal 2, lines.size
  end

  def test_a_failing_command_exits_1_and_ctrl_c_exits_130
    result = run_cli(program { progress(total: 10, title: "Uploading") { raise "network down" } })
    assert_equal 1, result.code
    assert_equal "✖ network down\n", result.err
    assert_match(/\A✖ Uploading 0\/10 #{TIME}\n\z/o, result.out)

    result = run_cli(program { progress(total: 10, title: "Waiting") { raise Interrupt } })
    assert_equal 130, result.code
    assert_match(/\A✖ Waiting/, result.out)
  end

  def test_in_a_command_say_prints_and_helpers_are_available
    tool = CLI::Program.build("tool") do
      argument :app
      run do
        progress(total: 2, title: "Deploying #{args[:app]}") do |bar|
          say "inside"
          bar.advance(2)
        end
      end
    end
    result = run_cli(tool, "api")
    assert_equal 0, result.code
    lines = result.out.lines(chomp: true)
    assert_equal "inside", lines[0]
    assert_match(/\A✔ Deploying api 2 #{TIME}\z/o, lines.last)
  end

  def test_needs_a_block_and_a_sane_total
    with_shell do
      assert_raises(ArgumentError) { CLI.progress(total: 10) }
      assert_raises(ArgumentError) { CLI.progress(total: -1) { nil } }
      assert_raises(ArgumentError) { CLI.progress(total: "10") { nil } }
    end
  end

  # ---- on a terminal ----

  def test_terminal_draws_a_bar_with_percent_and_amount_then_resolves
    seen = nil
    value, shell = with_shell(tty: true) do |s|
      CLI.progress(total: 10_000_000, title: "Downloading", unit: :bytes) do |bar|
        bar.current = 4_200_000
        seen = screen_text(s.output.string).first
        bar.current = 10_000_000
        :done
      end
    end
    assert_equal :done, value

    assert_equal 1, seen.size
    assert_match(/\ADownloading #{BAR} 42% 4\.2\/10 MB\z/o, seen[0])
    assert_match(/\ADownloading [━╸]+─+ /, seen[0]) # filled, then the track

    lines, vt = screen_text(shell.output.string)
    assert_equal 1, lines.size
    assert_match(/\A✔ Downloading 10 MB #{TIME}\z/o, lines[0])
    assert vt.cursor_visible?
    assert_includes shell.output.string, CLI::Live::HIDE_CURSOR
  end

  def test_terminal_shows_rate_and_eta_once_it_has_a_rate
    seen = nil
    with_shell(tty: true) do |s|
      CLI.progress(total: 10_000_000, title: "Downloading", unit: :bytes) do |bar|
        bar.advance(1_000_000)
        sleep 0.3
        bar.advance(1_000_000)
        seen = screen_text(s.output.string).first
      end
    end
    assert_match(%r{\ADownloading #{BAR} 20% 2/10 MB · [\d.]+ MB/s · ETA (\d+s|\d+m \d+s)\z}o, seen[0])
  end

  def test_terminal_bar_fits_the_width
    [80, 50, 30].each do |cols|
      seen = nil
      with_shell(tty: true, width: cols) do |s|
        CLI.progress(total: 100, title: "Downloading") do |bar|
          bar.current = 50
          seen = screen_text(s.output.string, cols: 200).first
        end
      end
      assert_equal 1, seen.size, "width #{cols}"
      assert_operator Lipgloss.width(seen[0]), :<, cols, "width #{cols}: #{seen[0].inspect}"
      assert_match(/\ADownloading #{BAR} 50%/o, seen[0])
    end
  end

  def test_terminal_indeterminate_bar_has_no_percent
    seen = nil
    _, shell = with_shell(tty: true) do |s|
      CLI.progress(title: "Waiting", unit: :bytes) do |bar|
        bar.advance(1_500_000)
        sleep 0.2 # let the ticker draw a frame
        seen = screen_text(s.output.string).first
      end
    end
    assert_equal 1, seen.size
    assert_match(/\AWaiting #{BAR} 1\.5 MB/o, seen[0])
    refute_includes seen[0], "%"
    lines, = screen_text(shell.output.string)
    assert_match(/\A✔ Waiting 1\.5 MB #{TIME}\z/o, lines[0])
  end

  def test_terminal_never_prints_milestone_lines
    _, shell = with_shell(tty: true) do
      CLI.progress(total: 100, title: "Processing") { |bar| 100.times { bar.advance } }
    end
    lines, = screen_text(shell.output.string)
    assert_equal 1, lines.size
    assert_match(/\A✔ Processing 100 #{TIME}\z/o, lines[0])
  end

  def test_terminal_failure_restores_the_cursor
    result = run_cli(program { progress(total: 10, title: "Uploading") { |b| b.advance(3); raise "network down" } },
                     tty: true)
    assert_equal 1, result.code
    assert_equal "✖ network down\n", result.err
    lines, vt = screen_text(result.out)
    assert_equal 1, lines.size
    assert_match(/\A✖ Uploading 3\/10 #{TIME}\z/o, lines[0])
    assert vt.cursor_visible?
    assert result.out.end_with?(CLI::Live::SHOW_CURSOR)
  end

  def test_terminal_say_inside_lands_above_the_bar
    _, shell = with_shell(tty: true) do
      CLI.progress(total: 2, title: "Building") do |bar|
        CLI.say "compiled"
        bar.advance(2)
      end
    end
    lines, = screen_text(shell.output.string)
    assert_equal "compiled", lines[0]
    assert_match(/\A✔ Building 2 #{TIME}\z/o, lines[1])
    assert_equal 2, lines.size
  end
end
