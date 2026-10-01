# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"

class CLIShellTest < Minitest::Test
  Shell = R2UI::CLI::Shell
  Theme = R2UI::CLI::Theme

  # An IO that reports itself as a terminal (no winsize, so width comes from COLUMNS/default).
  class FakeTTY < StringIO
    def tty? = true
  end

  def shell(input: StringIO.new, output: StringIO.new, error: StringIO.new, env: {}, **opts)
    Shell.new(input:, output:, error:, env:, **opts)
  end

  def with_ansi
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    yield
  ensure
    R2UI::Compat::Gloss::Renderer.color_profile = nil
  end

  # ---- tty?, live?, interactive?, input_tty? ----

  def test_pipes_are_not_a_terminal
    s = shell
    refute s.tty?
    refute s.live?
    refute s.interactive?
    refute s.input_tty?
  end

  def test_tty_from_the_ios
    s = shell(input: FakeTTY.new, output: FakeTTY.new)
    assert s.tty?
    assert s.live?
    assert s.input_tty?
    assert s.interactive?
  end

  def test_stdout_terminal_with_piped_stdin_is_not_interactive
    s = shell(output: FakeTTY.new)
    assert s.tty?
    refute s.input_tty?
    refute s.interactive?
  end

  def test_tty_override_wins_over_the_ios
    assert shell(tty: true).tty?
    refute shell(output: FakeTTY.new, tty: false).tty?
    # With only `tty:` given, stdin counts as a terminal too.
    assert shell(tty: true).input_tty?
    assert shell(tty: true).interactive?
  end

  def test_interactive_override
    refute shell(tty: true, interactive: false).interactive?
    refute shell(tty: true, interactive: false).input_tty?
    assert shell(interactive: true).interactive?
    assert shell(interactive: true).input_tty?
  end

  def test_term_dumb_is_a_tty_but_not_live
    s = shell(tty: true, env: { "TERM" => "dumb" })
    assert s.tty?
    refute s.live?
    refute s.interactive?
    assert shell(tty: true, interactive: true, env: { "TERM" => "dumb" }).interactive?
  end

  # ---- color? ----

  def test_color_follows_live
    assert shell(tty: true).color?
    refute shell.color?
    refute shell(tty: true, env: { "TERM" => "dumb" }).color?
  end

  def test_no_color_turns_colour_off
    refute shell(tty: true, env: { "NO_COLOR" => "1" }).color?
    refute shell(env: { "NO_COLOR" => "1", "FORCE_COLOR" => "1" }).color?
    # An empty NO_COLOR doesn't count.
    assert shell(tty: true, env: { "NO_COLOR" => "" }).color?
  end

  def test_force_color_turns_colour_on_in_a_pipe
    assert shell(env: { "FORCE_COLOR" => "1" }).color?
    refute shell(env: { "FORCE_COLOR" => "0" }).color?
    refute shell(env: { "FORCE_COLOR" => "" }).color?
  end

  def test_color_override_wins
    assert shell(color: true).color?
    refute shell(tty: true, color: false).color?
    assert shell(color: true, env: { "NO_COLOR" => "1" }).color?
    s = shell
    s.color = true
    assert s.color?
  end

  # ---- width ----

  def test_width
    assert_equal 80, shell.width
    assert_equal 120, shell(env: { "COLUMNS" => "120" }).width
    assert_equal 80, shell(env: { "COLUMNS" => "nope" }).width
    assert_equal 80, shell(env: { "COLUMNS" => "0" }).width
    assert_equal 42, shell(width: 42, env: { "COLUMNS" => "120" }).width
  end

  # ---- paint and symbols ----

  def test_paint_is_identity_without_colour
    s = shell
    assert_equal "hello", s.paint("hello", :success)
    assert_equal "a\nb", s.paint("a\nb", :error, :heading)
    assert_equal "42", s.paint(42, :info)
  end

  def test_paint_without_styles_is_identity_even_with_colour
    with_ansi { assert_equal "hello", shell(color: true).paint("hello") }
  end

  def test_paint_styles_each_line_with_colour
    with_ansi do
      s = shell(color: true)
      painted = s.paint("one\n\ntwo", :success)
      lines = painted.split("\n", -1)
      assert_equal 3, lines.size
      assert_includes lines[0], "one"
      assert_match(/\e\[[\d;]*m/, lines[0])
      assert_equal "", lines[1]
      assert_includes lines[2], "two"
      assert_match(/\e\[[\d;]*m/, lines[2])
      # Each line resets its own styling, so lines keep their widths.
      assert_equal "one", lines[0].gsub(/\e\[[\d;]*m/, "")
      assert_equal "two", lines[2].gsub(/\e\[[\d;]*m/, "")
    end
  end

  def test_paint_unknown_style_raises_with_colour
    with_ansi { assert_raises(ArgumentError) { shell(color: true).paint("x", :nope) } }
  end

  def test_symbols
    s = shell
    assert_equal "✔", s.symbol(:success)
    assert_equal "✖", s.symbol(:error)
    assert_equal "⚠", s.symbol(:warn)
    assert_equal "ℹ", s.symbol(:info)
    assert_equal "○", s.symbol(:pending)
    assert_equal "–", s.symbol(:skipped)
    assert_raises(ArgumentError) { s.symbol(:nope) }
  end

  def test_symbol_is_painted_with_colour
    with_ansi do
      sym = shell(color: true).symbol(:success)
      assert_match(/\e\[/, sym)
      assert_equal "✔", sym.gsub(/\e\[[\d;]*m/, "")
    end
  end

  # ---- Theme ----

  def test_theme_symbol_overrides
    s = shell(theme: Theme.new(symbols: { success: "OK" }))
    assert_equal "OK", s.symbol(:success)
    assert_equal "✖", s.symbol(:error)
  end

  def test_theme_style_overrides
    theme = Theme.new(styles: { success: { bold: true }, brand: { foreground: "5" } })
    assert_equal({ bold: true }, theme.options(:success))
    assert_equal({ foreground: "5" }, theme.options(:brand))
    assert_equal({ foreground: "1" }, theme.options(:error))
    with_ansi do
      s = shell(color: true, theme:)
      assert_match(/\e\[[\d;]*1[;m]/, s.paint("x", :success))
      refute_equal "x", s.paint("x", :brand)
    end
  end

  # ---- puts / err_puts ----

  def test_puts_adds_one_newline
    s = shell
    s.puts("a")
    s.puts("b\n")
    s.puts
    s.puts(7)
    assert_equal "a\nb\n\n7\n", s.output.string
    assert_equal "", s.error.string
  end

  def test_puts_returns_nil
    assert_nil shell.puts("x")
  end

  def test_print_adds_nothing
    s = shell
    s.print("a")
    s.print(1)
    assert_equal "a1", s.output.string
  end

  def test_err_puts_writes_to_stderr
    s = shell
    s.err_puts("oops")
    s.err_puts("again\n")
    s.err_puts
    assert_equal "oops\nagain\n\n", s.error.string
    assert_equal "", s.output.string
  end
end
