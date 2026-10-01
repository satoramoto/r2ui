# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require_relative "../../../conformance/lib/vt"

class CLIPairsTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI

  # Lipgloss renders colour only with a colour profile; a real terminal has one.
  def setup = R2UI::Compat::Gloss::Renderer.color_profile = :ansi

  def teardown = R2UI::Compat::Gloss::Renderer.color_profile = nil

  # A terminal turns "\n" into "\r\n" (onlcr); the decoder takes the raw bytes.
  def screen(out)
    vt = Conformance::VT.new(cols: 80, rows: 20)
    vt.feed(out.gsub("\n", "\r\n"))
    vt
  end

  # Style runs on one screen row, as [first column, last column, style].
  def runs(vt, row) = vt.style_runs.select { |r, *| r == row }.map { |_, from, to, style| [from, to, style] }

  # ---- plain (pipe) output ----

  def test_keys_are_padded_to_the_longest
    value, shell = with_shell { CLI.pairs({ "Version" => "1.4.0", "Env" => "production" }) }
    assert_nil value
    assert_equal "Version  1.4.0\nEnv      production\n", shell.output.string
    assert_equal "", shell.error.string
  end

  def test_title_line_and_indented_pairs
    _, shell = with_shell { CLI.pairs({ "Version" => "1.4.0", "Env" => "production" }, title: "Deploy") }
    assert_equal "Deploy\n  Version  1.4.0\n  Env      production\n", shell.output.string
  end

  def test_nil_values_show_a_dash
    _, shell = with_shell { CLI.pairs({ "Region" => nil, "Env" => "staging" }) }
    assert_equal "Region  —\nEnv     staging\n", shell.output.string
  end

  def test_keys_and_values_may_be_any_object
    _, shell = with_shell { CLI.pairs({ replicas: 3, ok: true }) }
    assert_equal "replicas  3\nok        true\n", shell.output.string
  end

  def test_padding_uses_display_width
    _, shell = with_shell { CLI.pairs({ "名前" => "api", "Name" => "web", "Env" => "prod" }) }
    lines = shell.output.string.lines(chomp: true)
    assert_equal ["名前  api", "Name  web", "Env   prod"], lines
  end

  def test_multi_line_values_line_up_under_the_value_column
    _, shell = with_shell { CLI.pairs({ "Hosts" => "a.example\nb.example", "Env" => "prod" }) }
    assert_equal "Hosts  a.example\n       b.example\nEnv    prod\n", shell.output.string
  end

  def test_empty_value_leaves_no_trailing_spaces
    _, shell = with_shell { CLI.pairs({ "Notes" => "", "Env" => "prod" }) }
    assert_equal "Notes\nEnv    prod\n", shell.output.string
  end

  def test_array_of_pairs_keeps_order_and_duplicates
    _, shell = with_shell { CLI.pairs([%w[Tag v1], %w[Tag v2]]) }
    assert_equal "Tag  v1\nTag  v2\n", shell.output.string
  end

  def test_empty_pairs_print_only_the_title
    _, shell = with_shell { CLI.pairs({}, title: "Deploy") }
    assert_equal "Deploy\n", shell.output.string
    _, shell = with_shell { CLI.pairs({}) }
    assert_equal "", shell.output.string
  end

  def test_no_escape_codes_off_a_terminal
    _, shell = with_shell { CLI.pairs({ "Region" => nil, "Env" => "prod" }, title: "Deploy") }
    refute_includes shell.output.string, "\e"
  end

  def test_works_inside_a_command
    tool = CLI::Program.build("tool") { run { pairs({ "App" => "api" }, title: "Status") } }
    result = run_cli(tool)
    assert_equal 0, result.code
    assert_equal "Status\n  App  api\n", result.out
  end

  # ---- terminal output ----

  def test_terminal_has_the_same_text
    _, shell = with_shell(tty: true, color: true) do
      CLI.pairs({ "Version" => "1.4.0", "Env" => nil }, title: "Deploy")
    end
    vt = screen(shell.output.string)
    assert_equal ["Deploy", "  Version  1.4.0", "  Env      —"], vt.lines.reject(&:empty?)
  end

  def test_title_bold_keys_muted_values_plain
    _, shell = with_shell(tty: true, color: true) do
      CLI.pairs({ "Version" => "1.4.0", "Env" => nil }, title: "Deploy")
    end
    vt = screen(shell.output.string)
    assert_equal [[0, 5, "bold"]], runs(vt, 0)
    # "  Version  1.4.0": the key is faint, the value has no style.
    assert_equal [[2, 8, "faint"]], runs(vt, 1)
    # A nil value's dash is muted too.
    assert_equal [[2, 4, "faint"], [11, 11, "faint"]], runs(vt, 2)
  end

  def test_no_colour_on_a_terminal_with_no_color
    _, shell = with_shell(tty: true, env: { "NO_COLOR" => "1" }, color: nil) do
      CLI.pairs({ "Version" => "1.4.0" }, title: "Deploy")
    end
    assert_equal "Deploy\n  Version  1.4.0\n", shell.output.string
  end
end
