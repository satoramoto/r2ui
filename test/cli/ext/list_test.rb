# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require_relative "../../../conformance/lib/vt"

class CLIListTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI

  def with_ansi
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    yield
  ensure
    R2UI::Compat::Gloss::Renderer.color_profile = nil
  end

  def screen_lines(out, cols: 80)
    vt = Conformance::VT.new(cols:, rows: 20)
    vt.feed(out.gsub("\n", "\r\n")) # the terminal's onlcr: a plain puts is LF only
    vt.lines.map(&:rstrip).reject(&:empty?)
  end

  def printed(width: 80, **options, &block)
    _, shell = with_shell(width:, **options) { block.call }
    shell.output.string
  end

  # ---- plain (pipe) output ----

  def test_bullets
    out = printed { CLI.list(%w[rails pg puma]) }
    assert_equal "• rails\n• pg\n• puma\n", out
    refute_includes out, "\e"
  end

  def test_returns_nil_and_writes_only_stdout
    value, shell = with_shell { CLI.list(%w[a]) }
    assert_nil value
    assert_equal "", shell.error.string
  end

  def test_items_are_converted_to_strings
    assert_equal "• 1\n• api\n", printed { CLI.list([1, :api]) }
  end

  def test_empty_list_prints_nothing
    assert_equal "", printed { CLI.list([]) }
  end

  def test_numbered
    assert_equal "1. build\n2. test\n3. ship\n", printed { CLI.list(%w[build test ship], numbered: true) }
  end

  def test_numbers_are_right_aligned
    lines = printed { CLI.list((1..10).map { |i| "step #{i}" }, numbered: true) }.lines(chomp: true)
    assert_equal " 1. step 1", lines[0]
    assert_equal " 9. step 9", lines[8]
    assert_equal "10. step 10", lines[9]
  end

  # ---- wrapping ----

  def test_long_items_wrap_under_their_text_at_the_shell_width
    text = "the quick brown fox jumps over the lazy dog and keeps running"
    lines = printed(width: 24) { CLI.list([text, "short"]) }.lines(chomp: true)
    assert_equal ["• the quick brown fox", "  jumps over the lazy", "  dog and keeps running", "• short"], lines
    lines.each { |line| assert_operator Lipgloss.width(line), :<=, 24 }
  end

  def test_numbered_items_wrap_under_their_text
    items = (1..10).map { |i| "item #{i}" }
    items[9] = "a tenth item that is much too long to fit"
    lines = printed(width: 20) { CLI.list(items, numbered: true) }.lines(chomp: true)
    assert_equal "10. a tenth item", lines[10 - 1]
    assert_equal "    that is much too", lines[10]
    assert_equal "    long to fit", lines[11]
  end

  def test_words_longer_than_the_line_are_broken
    lines = printed(width: 10) { CLI.list(["abcdefghijklmnop"]) }.lines(chomp: true)
    assert_equal ["• abcdefgh", "  ijklmnop"], lines
  end

  def test_wide_characters_wrap_by_display_width
    lines = printed(width: 8) { CLI.list(["漢字 漢字 漢字"]) }.lines(chomp: true)
    assert_equal ["• 漢字", "  漢字", "  漢字"], lines.map(&:rstrip)
    lines.each { |line| assert_operator Lipgloss.width(line), :<=, 8 }
  end

  def test_newlines_in_an_item_stay_under_its_text
    assert_equal "• first line\n  second line\n• next\n",
                 printed { CLI.list(["first line\nsecond line", "next"]) }
  end

  # ---- nesting ----

  def test_nested_arrays_indent_a_level
    out = printed { CLI.list(["app", %w[rails pg], "worker", ["sidekiq", ["redis"]]]) }
    assert_equal <<~TEXT, out
      • app
        • rails
        • pg
      • worker
        • sidekiq
          • redis
    TEXT
  end

  def test_nested_numbered_lists_number_from_one_under_the_parent_text
    out = printed { CLI.list(["Build", %w[compile link], "Ship"], numbered: true) }
    assert_equal <<~TEXT, out
      1. Build
         1. compile
         2. link
      2. Ship
    TEXT
  end

  def test_nested_items_wrap_under_their_own_text
    lines = printed(width: 20) { CLI.list(["parent", ["a nested item that wraps"]]) }.lines(chomp: true)
    assert_equal ["• parent", "  • a nested item", "    that wraps"], lines
  end

  # ---- on a terminal ----

  def test_terminal_bullets_are_in_the_accent_colour
    with_ansi do
      _, shell = with_shell(tty: true, color: true) { CLI.list(%w[rails pg]) }
      out = shell.output.string
      accent = shell.paint("•", :accent)
      refute_equal "•", accent
      assert out.start_with?("#{accent} rails\n")
      assert_equal ["• rails", "• pg"], screen_lines(out)
    end
  end

  def test_terminal_numbers_are_in_the_accent_colour_and_wrap_the_same
    with_ansi do
      _, shell = with_shell(tty: true, color: true, width: 16) do
        CLI.list(["one", "a second item that wraps"], numbered: true)
      end
      out = shell.output.string
      assert_includes out, shell.paint("2.", :accent)
      assert_equal ["1. one", "2. a second item", "   that wraps"], screen_lines(out, cols: 16)
    end
  end

  # ---- in a command ----

  def test_in_a_command
    tool = CLI::Program.build("tool") do
      argument :names, many: true
      run { list(args[:names], numbered: true) }
    end
    result = run_cli(tool, "api", "web")
    assert_equal 0, result.code
    assert_equal "1. api\n2. web\n", result.out
  end

  def test_items_must_be_an_array
    with_shell { assert_raises(ArgumentError) { CLI.list("rails") } }
  end
end
