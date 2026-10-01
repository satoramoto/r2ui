# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require_relative "../../../conformance/lib/vt"

class CLITableTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI

  ROWS = [["rails", "7.1.0", "12 kB"], ["pg", "1.5", "1.2 MB"]].freeze
  HEADERS = %w[Name Version Size].freeze

  # A terminal's tty driver turns "\n" into "\r\n" (onlcr); the VT decoder doesn't.
  def screen(out, cols: 80)
    vt = Conformance::VT.new(cols:, rows: 30)
    vt.feed(out.gsub("\n", "\r\n"))
    vt.lines.map(&:rstrip).reject(&:empty?)
  end

  def width(line) = Lipgloss.width(line)

  def with_ansi
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    yield
  ensure
    R2UI::Compat::Gloss::Renderer.color_profile = nil
  end

  # ---- plain (pipe) output ----

  def test_plain_columns_aligned_with_two_spaces
    value, shell = with_shell { CLI.table(ROWS, headers: HEADERS) }
    assert_nil value
    assert_equal <<~OUT, shell.output.string
      Name   Version  Size
      rails  7.1.0    12 kB
      pg     1.5      1.2 MB
    OUT
    assert_equal "", shell.error.string
  end

  def test_plain_without_headers
    _, shell = with_shell { CLI.table(ROWS) }
    assert_equal "rails  7.1.0  12 kB\npg     1.5    1.2 MB\n", shell.output.string
  end

  def test_plain_is_awk_friendly
    _, shell = with_shell { CLI.table([["a b", nil, 3], ["line\nbreak", :sym, 4.5]], headers: %w[x y z]) }
    out = shell.output.string
    refute_includes out, "\e"
    refute_match(/[│─╭╮╰╯┼├┤]/, out)
    lines = out.lines(chomp: true)
    assert_equal 3, lines.size
    lines.each { |line| refute_match(/\s\z/, line, "no trailing spaces: #{line.inspect}") }
    assert_equal "line break  sym  4.5", lines[2]
    assert_equal "a b              3", lines[1] # "a b" padded to 10, "" to 3, two-space gaps
  end

  def test_hash_rows_take_headers_from_keys
    rows = [{ name: "rails", version: "7.1.0" }, { name: "pg", size: "1.2 MB" }]
    _, shell = with_shell { CLI.table(rows) }
    assert_equal <<~OUT, shell.output.string
      name   version  size
      rails  7.1.0
      pg              1.2 MB
    OUT
  end

  def test_hash_rows_with_given_headers_pick_and_order_columns
    rows = [{ "name" => "rails", "version" => "7.1.0", "extra" => "x" }]
    _, shell = with_shell { CLI.table(rows, headers: %w[version name]) }
    assert_equal "version  name\n7.1.0    rails\n", shell.output.string
  end

  def test_right_aligned_column
    _, shell = with_shell { CLI.table(ROWS, headers: HEADERS, align: { 2 => :right }) }
    assert_equal <<~OUT, shell.output.string
      Name   Version    Size
      rails  7.1.0     12 kB
      pg     1.5      1.2 MB
    OUT
  end

  def test_align_by_header_name
    _, shell = with_shell { CLI.table(ROWS, headers: HEADERS, align: { "Size" => :right }) }
    assert_equal "  Size", shell.output.string.lines.first.chomp[-6..]
  end

  def test_wide_characters_keep_columns_aligned
    _, shell = with_shell { CLI.table([["日本語", "ja"], ["en", "en"]], headers: %w[Name Code]) }
    lines = shell.output.string.lines(chomp: true)
    columns = lines.map { |line| width(line[0...line.index(/\S+\z/)]) }
    assert_equal [columns.first] * 3, columns
  end

  def test_ragged_rows_are_padded
    _, shell = with_shell { CLI.table([["a"], %w[b c d]]) }
    assert_equal "a\nb  c  d\n", shell.output.string
  end

  def test_empty_rows_print_just_the_header
    _, shell = with_shell { CLI.table([], headers: HEADERS) }
    assert_equal "Name  Version  Size\n", shell.output.string
  end

  def test_nothing_at_all_prints_nothing
    _, shell = with_shell { CLI.table([]) }
    assert_equal "", shell.output.string
  end

  def test_in_a_command_goes_to_stdout
    tool = CLI::Program.build("tool") { run { table([%w[api up]], headers: %w[App State]) } }
    result = run_cli(tool)
    assert_equal 0, result.code
    assert_equal "App  State\napi  up\n", result.out
    assert_equal "", result.err
  end

  def test_bad_align_raises
    with_shell do
      assert_raises(ArgumentError) { CLI.table(ROWS, align: { 0 => :middle }) }
    end
  end

  # ---- on a terminal ----

  def test_terminal_draws_a_rounded_border_with_the_header
    _, shell = with_shell(tty: true) { CLI.table(ROWS, headers: HEADERS) }
    lines = screen(shell.output.string)
    assert_equal 6, lines.size
    assert_match(/\A╭─+┬─+┬─+╮\z/, lines[0])
    assert_equal "│ Name  │ Version │ Size   │", lines[1]
    assert_match(/\A├─+┼─+┼─+┤\z/, lines[2])
    assert_equal "│ rails │ 7.1.0   │ 12 kB  │", lines[3]
    assert_equal "│ pg    │ 1.5     │ 1.2 MB │", lines[4]
    assert_match(/\A╰─+┴─+┴─+╯\z/, lines[5])
  end

  def test_terminal_right_alignment
    _, shell = with_shell(tty: true) { CLI.table(ROWS, headers: HEADERS, align: { 2 => :right }) }
    lines = screen(shell.output.string)
    assert_equal "│ Name  │ Version │   Size │", lines[1]
    assert_equal "│ rails │ 7.1.0   │  12 kB │", lines[3]
  end

  def test_terminal_fits_the_width
    rows = [["api", "x" * 60, "y" * 40], ["web", "short", "z" * 50]]
    _, shell = with_shell(tty: true, width: 50) { CLI.table(rows, headers: %w[App Notes More]) }
    lines = screen(shell.output.string, cols: 200)
    assert(lines.all? { |line| width(line) <= 50 }, lines.join("\n"))
    assert_equal lines.first.size, lines.last.size
    assert_match(/\A╭/, lines.first)
    assert_match(/╯\z/, lines.last)
  end

  def test_terminal_narrow_table_is_not_stretched
    _, shell = with_shell(tty: true, width: 120) { CLI.table([%w[a b]]) }
    lines = screen(shell.output.string)
    assert_equal ["╭───┬───╮", "│ a │ b │", "╰───┴───╯"], lines
  end

  def test_terminal_empty_rows_draw_just_the_header
    _, shell = with_shell(tty: true) { CLI.table([], headers: %w[Name Size]) }
    lines = screen(shell.output.string)
    assert_includes lines, "│ Name │ Size │"
    assert_match(/\A╭/, lines.first)
    assert_match(/╯\z/, lines.last)
    refute(lines.any? { |line| line.start_with?("├") })
  end

  def test_terminal_header_is_bold_with_colour
    _, shell = with_ansi { with_shell(tty: true, color: true) { CLI.table(ROWS, headers: HEADERS) } }
    out = shell.output.string
    assert_match(/\e\[[0-9;]*1[0-9;]*m\s*Name/, out)
    assert_equal "│ Name  │ Version │ Size   │", screen(out)[1]
  end

  def test_terminal_without_colour_has_no_styling_escapes
    _, shell = with_ansi { with_shell(tty: true, color: false) { CLI.table(ROWS, headers: HEADERS) } }
    refute_includes shell.output.string, "\e"
  end

  def test_terminal_dumb_is_plain
    _, shell = with_shell(tty: true, env: { "TERM" => "dumb" }) { CLI.table(ROWS, headers: HEADERS) }
    assert_equal "Name   Version  Size\n", shell.output.string.lines.first
  end
end
