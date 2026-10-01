# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require_relative "../../../conformance/lib/vt"

# c31-color-option: `color_option` on the root adds --color/--no-color.
class CLIColorOptionTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI
  SGR = /\e\[[\d;]*m/ # a colour/style escape; cursor movement is other CSI codes

  def teardown
    R2UI::Compat::Gloss::Renderer.color_profile = nil
  end

  def tool(&block)
    CLI::Program.build("tool") do
      color_option
      command :status, "Show status" do
        run { say "all good", :success }
      end
      command :deploy, "Deploy" do
        argument :app
        run { say "deployed" }
      end
      command :steps, "Run steps" do
        run(&block) if block
      end
      command :fail, "Fail" do
        run { raise "boom" }
      end
    end
  end

  def screen(out)
    vt = Conformance::VT.new(cols: 80, rows: 20)
    vt.feed(out.gsub(/(?<!\r)\n/, "\r\n"))
    vt.lines.map(&:rstrip).reject(&:empty?)
  end

  # ---- help ----

  def test_help_lists_the_option
    out = run_cli(tool, "--help").out
    assert_match(/--color\s+\S/, out)
    refute_match(/default: false/, out)
  end

  def test_without_the_keyword_there_is_no_option
    plain = CLI::Program.build("tool") { run { say "hi" } }
    refute_includes run_cli(plain, "--help").out, "--color"
    result = run_cli(plain, "--no-color")
    assert_equal 2, result.code
  end

  def test_keyword_belongs_on_the_root
    error = assert_raises(ArgumentError) do
      CLI::Program.build("tool") { command(:x) { color_option } }
    end
    assert_includes error.message, "root"
  end

  # ---- on a terminal ----

  def test_terminal_is_coloured_without_the_flag
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    result = run_cli(tool, "status", tty: true, color: nil)
    assert_match SGR, result.out
  end

  def test_no_color_on_a_terminal_prints_no_colour_codes
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    result = run_cli(tool, "status", "--no-color", tty: true, color: nil)
    assert_equal 0, result.code
    assert_equal "all good\n", result.out
  end

  def test_no_color_before_the_command_name_works_too
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    result = run_cli(tool, "--no-color", "status", tty: true, color: nil)
    assert_equal "all good\n", result.out
  end

  def test_no_color_keeps_live_redraw
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    result = run_cli(tool { tasks { step("Building") { sleep 0.15 } } }, "steps", "--no-color", tty: true, color: nil)
    assert_equal 0, result.code
    refute_match SGR, result.out
    assert_includes result.out, "\e[", "live redraw still moves the cursor"
    lines = screen(result.out)
    assert_match(/\A✔ Building \S+\z/, lines.last)
  end

  def test_no_color_errors_are_plain
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    result = run_cli(tool, "fail", "--no-color", tty: true, color: nil)
    assert_equal 1, result.code
    assert_equal "✖ boom\n", result.err
  end

  def test_no_color_usage_errors_after_parsing_are_plain
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    result = run_cli(tool, "deploy", "--no-color", tty: true, color: nil)
    assert_equal 2, result.code
    refute_match SGR, result.err
    assert_includes result.err, "✖ "
  end

  # ---- in a pipe ----

  def test_pipe_is_plain_without_the_flag
    result = run_cli(tool, "status", color: nil)
    assert_equal "all good\n", result.out
  end

  def test_color_styles_output_in_a_pipe
    R2UI::Compat::Gloss::Renderer.color_profile = :ascii # what lipgloss detects on a piped stdout
    result = run_cli(tool, "status", "--color", color: nil)
    assert_equal 0, result.code
    assert_match SGR, result.out
    assert_includes result.out, "all good"
    refute_includes result.out, "\e[?25l", "no live redraw in a pipe"
  end

  def test_color_beats_no_color_in_the_environment
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    result = run_cli(tool, "status", "--color", color: nil, env: { "NO_COLOR" => "1" })
    assert_match SGR, result.out
  end

  def test_no_color_beats_force_color_in_the_environment
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    result = run_cli(tool, "status", "--no-color", color: nil, env: { "FORCE_COLOR" => "1" })
    assert_equal "all good\n", result.out
  end

  def test_the_last_one_given_wins
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    result = run_cli(tool, "status", "--color", "--no-color", tty: true, color: nil)
    assert_equal "all good\n", result.out
  end
end
