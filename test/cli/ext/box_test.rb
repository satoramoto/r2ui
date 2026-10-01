# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"

class CLIBoxTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI
  ANSI = /\e\[[0-9;]*m/

  def teardown
    R2UI::Compat::Gloss::Renderer.color_profile = nil
  end

  def box(*args, shell: {}, **opts)
    _, s = with_shell(**shell) { CLI.box(*args, **opts) }
    s.output.string
  end

  def widths(out) = out.lines(chomp: true).map { |l| Lipgloss.width(l) }

  # ---- plain (pipe) output ----

  def test_rounded_box_with_default_padding
    expected = <<~BOX
      ╭─────────╮
      │         │
      │  Hello  │
      │         │
      ╰─────────╯
    BOX
    assert_equal expected, box("Hello")
  end

  def test_title_sits_in_the_top_border
    expected = <<~BOX
      ╭─ Next steps ─╮
      │Created app   │
      │              │
      │  cd app      │
      ╰──────────────╯
    BOX
    assert_equal expected, box("Created app\n\n  cd app", title: "Next steps", padding: 0)
  end

  def test_padding_as_vertical_and_horizontal
    expected = <<~BOX
      ╭─────╮
      │ hi  │
      │ yo! │
      ╰─────╯
    BOX
    assert_equal expected, box("hi\nyo!", padding: [0, 1])
  end

  def test_multi_line_and_wide_characters_keep_the_right_edge
    out = box("Update available 1.2.0 → 1.3.0\n日本語のテキスト\n\tRun npm i -g tool", title: "更新")
    lines = out.lines(chomp: true)
    assert_equal 1, widths(out).uniq.size, out
    assert(lines[1..-2].all? { |l| l.start_with?("│") && l.end_with?("│") }, out)
    assert lines[0].start_with?("╭─ 更新 ─")
    assert lines[0].end_with?("╮")
    assert lines[-1].start_with?("╰") && lines[-1].end_with?("╯")
    assert_includes out, "日本語のテキスト"
  end

  def test_never_wider_than_the_shell
    text = "A new version of deployer is available. Run gem update deployer to get the fix for " \
           "the replica restart bug and the faster uploads."
    out = box(text, title: "Update available", shell: { width: 40 })
    assert(widths(out).all? { |w| w == 40 }, out)
    words = out.lines.map { |l| l.delete("│╭╮╰╯─").strip }.join(" ").split
    assert_equal text.split, words - %w[Update available]
  end

  def test_width_sets_the_outer_width_capped_at_the_shell
    assert(widths(box("short", width: 30)).all? { |w| w == 30 })
    assert(widths(box("short", width: 200, shell: { width: 50 })).all? { |w| w == 50 })
  end

  def test_unbreakable_words_wrap_inside_the_box
    out = box("x" * 100, shell: { width: 30 })
    assert(widths(out).all? { |w| w == 30 }, out)
    assert_equal 100, out.count("x")
  end

  def test_a_title_too_wide_for_the_top_border_becomes_the_first_line
    out = box("body", title: "A very long title that cannot fit", padding: 0, shell: { width: 20 })
    lines = out.lines(chomp: true)
    assert_equal "╭" + ("─" * 18) + "╮", lines[0]
    assert(widths(out).all? { |w| w == 20 }, out)
    assert_includes lines[1], "A very long title"
    assert_includes out, "body"
    assert out.index("cannot fit") < out.index("body")
  end

  def test_empty_text_still_draws_a_box
    expected = <<~BOX
      ╭──╮
      │  │
      ╰──╯
    BOX
    assert_equal expected, box("", padding: [0, 1])
  end

  def test_no_escape_codes_off_a_terminal
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    out = box("Hello", title: "Note", style: :warn)
    refute_includes out, "\e"
  end

  def test_from_a_command_it_prints_to_stdout
    tool = CLI::Program.build("tool") { run { box("Deployed", title: "Done", style: :success) } }
    result = run_cli(tool)
    assert_equal 0, result.code
    assert_equal "", result.err
    assert_includes result.out, "╭─ Done ─"
    assert_includes result.out, "Deployed"
  end

  def test_returns_nil
    value, = with_shell { CLI.box("x") }
    assert_nil value
  end

  # ---- on a terminal ----

  def test_terminal_border_and_title_in_the_style_colour_with_the_same_layout
    plain = box("Hello\nworld", title: "Note", style: :info)
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    out = box("Hello\nworld", title: "Note", style: :info, shell: { tty: true, color: true })
    assert_includes out, "\e[34m"
    assert_equal plain, out.gsub(ANSI, "")
    # The text itself isn't coloured: escapes only wrap border and title.
    hello = out.lines.find { |l| l.include?("Hello") }
    assert_match(/\A\e\[[0-9;]*m│\e\[0?m  Hello/, hello)
  end

  def test_terminal_styles_pick_their_colours
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    assert_includes box("x", style: :error, shell: { tty: true, color: true }), "\e[31m"
    assert_includes box("x", style: :success, shell: { tty: true, color: true }), "\e[32m"
  end

  # ---- misuse ----

  def test_unknown_style_raises
    with_shell { assert_raises(ArgumentError) { CLI.box("x", style: :nope) } }
  end
end
