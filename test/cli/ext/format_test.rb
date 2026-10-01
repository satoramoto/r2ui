# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require_relative "../../../conformance/lib/vt"

class CLIFormatTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI

  # ---- duration ----

  def test_duration_minutes_and_seconds
    assert_equal "1m 15s", CLI.duration(75.2)
  end

  def test_duration_milliseconds_under_a_second
    assert_equal "0ms", CLI.duration(0)
    assert_equal "120ms", CLI.duration(0.12)
    assert_equal "999ms", CLI.duration(0.9991)
  end

  def test_duration_seconds_with_tenths_under_a_minute
    assert_equal "1.0s", CLI.duration(0.9996)
    assert_equal "3.5s", CLI.duration(3.456)
    assert_equal "59.9s", CLI.duration(59.94)
  end

  def test_duration_rounds_before_picking_the_unit
    assert_equal "1m 0s", CLI.duration(59.97)
    assert_equal "1h 0m", CLI.duration(3599.6)
  end

  def test_duration_hours_and_days
    assert_equal "1h 1m", CLI.duration(3661)
    assert_equal "2h 30m", CLI.duration(9000)
    assert_equal "1d 2h", CLI.duration(93_600)
  end

  def test_duration_negative
    assert_equal "-1m 15s", CLI.duration(-75)
  end

  # ---- bytes ----

  def test_bytes_decimal_units
    assert_equal "1.5 MB", CLI.bytes(1_500_000)
    assert_equal "0 B", CLI.bytes(0)
    assert_equal "999 B", CLI.bytes(999)
    assert_equal "1 kB", CLI.bytes(1000)
    assert_equal "12 kB", CLI.bytes(12_345)
    assert_equal "123 MB", CLI.bytes(123_456_789)
    assert_equal "4.2 GB", CLI.bytes(4_200_000_000)
    assert_equal "2 TB", CLI.bytes(2 * 10**12)
  end

  def test_bytes_rounding_moves_to_the_next_unit
    assert_equal "1 MB", CLI.bytes(999_999)
    assert_equal "10 kB", CLI.bytes(9_999)
  end

  def test_bytes_negative
    assert_equal "-1.5 MB", CLI.bytes(-1_500_000)
  end

  # ---- ibytes ----

  def test_ibytes_binary_units_like_the_dashboard
    assert_equal "999B", CLI.ibytes(999)
    assert_equal "1.0K", CLI.ibytes(1000)
    assert_equal "1.5K", CLI.ibytes(1536)
    assert_equal "10K", CLI.ibytes(10_240)
    assert_equal "1.0M", CLI.ibytes(1_024_000)
    assert_equal "-2.0K", CLI.ibytes(-2048)
  end

  # ---- HumanFormat delegates (back compat) ----

  def test_human_format_delegates
    hf = CLI::Ext::HumanFormat
    assert_equal "1m 15s", hf.duration(75.2)
    assert_equal "1.5 MB", hf.bytes(1_500_000)
    assert_equal "2 boxes", hf.plural(2, "box")
    assert_equal "1,234", hf.delimit(1234)
  end

  # ---- plural ----

  def test_plural
    assert_equal "3 packages", CLI.plural(3, "package")
    assert_equal "1 package", CLI.plural(1, "package")
    assert_equal "0 packages", CLI.plural(0, "package")
  end

  def test_plural_with_an_irregular_form
    assert_equal "1 child", CLI.plural(1, "child", "children")
    assert_equal "2 children", CLI.plural(2, "child", "children")
  end

  def test_plural_regular_english_endings
    assert_equal "2 dependencies", CLI.plural(2, "dependency")
    assert_equal "2 boxes", CLI.plural(2, "box")
    assert_equal "2 matches", CLI.plural(2, "match")
    assert_equal "2 days", CLI.plural(2, "day")
  end

  def test_plural_groups_thousands
    assert_equal "1,234 packages", CLI.plural(1234, "package")
    assert_equal "1,000,000 files", CLI.plural(1_000_000, "file")
  end

  # ---- link ----

  def test_link_off_a_terminal_is_text_and_url
    value, = with_shell { CLI.link("https://example.com/pr/1", "PR #1") }
    assert_equal "PR #1 (https://example.com/pr/1)", value
  end

  def test_link_without_text_is_the_url
    value, = with_shell { CLI.link("https://example.com") }
    assert_equal "https://example.com", value
  end

  def test_link_with_colour_is_an_osc8_hyperlink
    value, = with_shell(tty: true, color: true) { CLI.link("https://example.com/pr/1", "PR #1") }
    assert_equal "\e]8;;https://example.com/pr/1\e\\PR #1\e]8;;\e\\", value

    vt = Conformance::VT.new(cols: 80, rows: 2)
    vt.feed(value)
    assert_equal "PR #1", vt.lines.first.rstrip
  end

  def test_link_follows_no_color_on_a_terminal
    value, = with_shell(tty: true, env: { "NO_COLOR" => "1" }) do |shell|
      shell.color = nil
      CLI.link("https://example.com", "site")
    end
    assert_equal "site (https://example.com)", value
  end

  # ---- in a command ----

  def test_helpers_in_a_command
    program = CLI::Program.build("tool") do
      run { say "added #{plural(3, "package")} (#{bytes(1_500_000)}) in #{duration(75.2)}, see #{link("https://x.dev", "docs")}" }
    end
    result = run_cli(program)
    assert_equal 0, result.code
    assert_equal "added 3 packages (1.5 MB) in 1m 15s, see docs (https://x.dev)\n", result.out
  end
end
