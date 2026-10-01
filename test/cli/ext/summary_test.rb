# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require_relative "../../../conformance/lib/vt"

class CLISummaryTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI
  TIME = /(\d+)ms|(\d+\.\d)s|(\d+)m (\d+)s/
  SGR = /\e\[[\d;]*m/

  def program(&block) = CLI::Program.build("tool") { run(&block) }

  # "120ms" / "3.5s" / "1m 15s" → seconds.
  def seconds(text)
    m = TIME.match(text) or flunk("no duration in #{text.inspect}")
    return m[1].to_i / 1000.0 if m[1]
    return m[2].to_f if m[2]

    (m[3].to_i * 60) + m[4].to_i
  end

  def with_ansi
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    yield
  ensure
    R2UI::Compat::Gloss::Renderer.color_profile = nil
  end

  # ---- heading ----

  def test_heading_prints_the_line_and_a_blank_line
    result = run_cli(program { heading "deployer v1.4.0"; say "next" })
    assert_equal 0, result.code
    assert_equal "deployer v1.4.0\n\nnext\n", result.out
    assert_equal "", result.err
  end

  def test_heading_is_bold_on_a_terminal
    with_ansi do
      result = run_cli(program { heading "deployer v1.4.0" }, tty: true, color: true)
      first, blank = result.out.split("\n", -1)
      assert_includes first, "\e[1m"
      assert_equal "deployer v1.4.0", first.gsub(SGR, "")
      assert_equal "", blank
    end
  end

  def test_heading_in_a_script
    _, shell = with_shell { CLI.heading("tool v2") }
    assert_equal "tool v2\n\n", shell.output.string
  end

  # ---- done ----

  def test_done_prints_the_message_and_the_time_since_the_command_started
    result = run_cli(program { sleep 0.05; done("Deployed 3 apps") })
    assert_equal 0, result.code
    assert_match(/\A✔ Deployed 3 apps in #{TIME}\n\z/o, result.out)
    assert_operator seconds(result.out), :>=, 0.05
    refute_includes result.out, "\e"
    assert_equal "", result.err
  end

  def test_done_without_a_message
    result = run_cli(program { done(nil) })
    assert_match(/\ADone in #{TIME}\n\z/o, result.out)
    result = run_cli(program { done })
    assert_match(/\ADone in #{TIME}\n\z/o, result.out)
  end

  def test_the_clock_starts_with_the_command_not_the_heading
    result = run_cli(program { sleep 0.05; heading "tool"; done("Built") })
    lines = result.out.lines(chomp: true)
    assert_equal ["tool", ""], lines[0, 2]
    assert_match(/\A✔ Built in #{TIME}\z/o, lines[2])
    assert_operator seconds(lines[2]), :>=, 0.05
  end

  def test_each_command_run_has_its_own_clock
    run_cli(program { sleep 0.2 })
    result = run_cli(program { done("Quick") })
    assert_operator seconds(result.out), :<, 0.2
  end

  def test_done_in_a_script_counts_from_the_start
    # Work before the first summary helper still counts (the clock doesn't start at `done`).
    _, shell = with_shell do
      sleep 0.05
      CLI.done("Built")
    end
    assert_match(/\A✔ Built in #{TIME}\n\z/o, shell.output.string)
    assert_operator seconds(shell.output.string), :>=, 0.05
  end

  def test_done_after_tasks_reads_like_npm
    result = run_cli(program do
      tasks { step("Building") { nil } }
      done("Built 1 app")
    end)
    lines = result.out.lines(chomp: true)
    assert_equal 2, lines.size
    assert_match(/\A✔ Building #{TIME}\z/o, lines[0])
    assert_match(/\A✔ Built 1 app in #{TIME}\z/o, lines[1])
  end

  def test_done_is_styled_on_a_terminal
    with_ansi do
      result = run_cli(program { done("Deployed") }, tty: true, color: true)
      line = result.out.chomp
      assert_match(/\e\[[\d;]*m✔/, line)
      assert_match(/\e\[[\d;]*m in #{TIME}/o, line)
      assert_match(/\A✔ Deployed in #{TIME}\z/o, line.gsub(SGR, ""))
    end
  end

  def test_done_and_heading_inside_a_live_list_land_above_it
    result = run_cli(program do
      tasks do
        step("Building") { heading "inside"; done("Halfway") }
      end
    end, tty: true)
    vt = Conformance::VT.new(cols: 80, rows: 20)
    vt.feed(result.out)
    lines = vt.lines.map(&:rstrip)
    assert_equal "inside", lines[0]
    assert_equal "", lines[1]
    assert_match(/\A✔ Halfway in #{TIME}\z/o, lines[2])
    assert_match(/\A✔ Building #{TIME}\z/o, lines[3])
    assert vt.cursor_visible?
  end
end
