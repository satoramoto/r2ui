# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"

class CLIDiffTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI

  def teardown
    R2UI::Compat::Gloss::Renderer.color_profile = nil
  end

  def diff_out(old, new, **options)
    value, shell = with_shell { CLI.diff(old, new, **options) }
    [value, shell.output.string]
  end

  def numbered(range) = range.map { |i| "line #{i}\n" }.join

  # ---- plain (pipe) output ----

  def test_equal_texts_print_nothing_and_return_false
    value, out = diff_out("a\nb\n", "a\nb\n")
    assert_equal false, value
    assert_equal "", out
  end

  def test_one_changed_line
    value, out = diff_out("a\nb\nc\n", "a\nB\nc\n")
    assert_equal true, value
    assert_equal <<~DIFF, out
      --- a
      +++ b
      @@ -1,3 +1,3 @@
       a
      -b
      +B
       c
    DIFF
  end

  def test_labels
    _, out = diff_out("x\n", "y\n", labels: ["config.yml (deployed)", "config.yml (local)"])
    assert_equal <<~DIFF, out
      --- config.yml (deployed)
      +++ config.yml (local)
      @@ -1 +1 @@
      -x
      +y
    DIFF
  end

  def test_context_limits_and_splits_hunks
    old = numbered(1..20)
    new = old.sub("line 3\n", "line three\n").sub("line 17\n", "")
    _, out = diff_out(old, new, context: 2)
    assert_equal <<~DIFF, out
      --- a
      +++ b
      @@ -1,5 +1,5 @@
       line 1
       line 2
      -line 3
      +line three
       line 4
       line 5
      @@ -15,5 +15,4 @@
       line 15
       line 16
      -line 17
       line 18
       line 19
    DIFF
  end

  def test_nearby_changes_share_a_hunk
    old = numbered(1..12)
    new = old.sub("line 4\n", "four\n").sub("line 9\n", "nine\n")
    _, out = diff_out(old, new) # default context: 3; gap of 4 unchanged lines < 2 * 3
    hunks = out.lines.grep(/\A@@/)
    assert_equal ["@@ -1,12 +1,12 @@\n"], hunks
  end

  def test_zero_context
    _, out = diff_out("a\nb\nc\n", "a\nc\nd\n", context: 0)
    assert_equal <<~DIFF, out
      --- a
      +++ b
      @@ -2 +1,0 @@
      -b
      @@ -3,0 +3 @@
      +d
    DIFF
  end

  def test_from_and_to_empty
    _, out = diff_out("", "one\ntwo\n")
    assert_equal "--- a\n+++ b\n@@ -0,0 +1,2 @@\n+one\n+two\n", out
    _, out = diff_out("one\n", "")
    assert_equal "--- a\n+++ b\n@@ -1 +0,0 @@\n-one\n", out
  end

  def test_missing_final_newline_is_marked
    _, out = diff_out("a\nb\n", "a\nb")
    assert_equal <<~DIFF, out
      --- a
      +++ b
      @@ -1,2 +1,2 @@
       a
      -b
      +b
      \\ No newline at end of file
    DIFF
  end

  def test_arrays_of_lines
    value, out = diff_out(%w[alpha beta], %w[alpha gamma])
    assert_equal true, value
    assert_equal "--- a\n+++ b\n@@ -1,2 +1,2 @@\n alpha\n-beta\n+gamma\n", out
  end

  def test_tabs_and_spacing_are_kept
    _, out = diff_out("\tindented  \n", "\tindented\n")
    assert_equal "--- a\n+++ b\n@@ -1 +1 @@\n-\tindented  \n+\tindented\n", out
  end

  def test_negative_context_is_an_argument_error
    assert_raises(ArgumentError) { with_shell { CLI.diff("a", "b", context: -1) } }
  end

  # The hunks rebuild both texts, and the edit is minimal (as long as an LCS says).
  def test_random_edits_rebuild_both_sides_minimally
    rng = Random.new(11)
    200.times do
      old = Array.new(rng.rand(0..12)) { %w[a b c d e][rng.rand(5)] }
      new = Array.new(rng.rand(0..12)) { %w[a b c d e][rng.rand(5)] }
      value, out = diff_out(old, new, context: 1_000)
      assert_equal old != new, value
      next if old == new

      body = out.lines(chomp: true).drop(3)
      assert_equal old, body.reject { |l| l.start_with?("+") }.map { |l| l[1..] }
      assert_equal new, body.reject { |l| l.start_with?("-") }.map { |l| l[1..] }
      changes = body.count { |l| !l.start_with?(" ") }
      assert_equal old.size + new.size - (2 * lcs_size(old, new)), changes
    end
  end

  def lcs_size(a, b)
    row = Array.new(b.size + 1, 0)
    a.each do |x|
      prev = 0
      b.each_with_index do |y, j|
        cur = row[j + 1]
        row[j + 1] = x == y ? prev + 1 : [row[j + 1], row[j]].max
        prev = cur
      end
    end
    row.last
  end

  def test_large_inputs_stay_fast
    old = numbered(1..20_000)
    new = old.sub("line 10000\n", "changed\n")
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    _, out = diff_out(old, new)
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 2
    assert_includes out, "@@ -9997,7 +9997,7 @@\n"
  end

  # ---- on a terminal ----

  def test_terminal_colours_and_same_text
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    old = "a\n\tb\nc\n"
    new = "a\n\tB\nc"
    _, plain_out = diff_out(old, new)
    value, shell = with_shell(tty: true, color: true) { CLI.diff(old, new) }
    out = shell.output.string
    assert_equal true, value
    lines = out.lines(chomp: true)
    assert_includes lines, "\e[31m-\e[0m\t\e[31mb\e[0m"
    assert_includes lines, "\e[32m+\e[0m\t\e[32mB\e[0m"
    assert lines.any? { |l| l.include?("\e[2m@@ -1,3 +1,3 @@\e[0m") }, out.inspect
    assert lines.any? { |l| l.include?("\e[1m") && l.include?("--- a") }, out.inspect
    assert_equal plain_out, out.gsub(/\e\[[\d;]*m/, "")
  end

  def test_no_colour_on_a_terminal_without_colour
    _, shell = with_shell(tty: true, color: false) { CLI.diff("a\n", "b\n") }
    refute_includes shell.output.string, "\e"
  end

  # ---- in a command ----

  def test_in_a_command_writes_to_stdout
    program = CLI::Program.build("tool") do
      run { say(diff("v1\n", "v2\n", labels: %w[old new]) ? "changed" : "same") }
    end
    result = run_cli(program)
    assert_equal 0, result.code
    assert_equal "--- old\n+++ new\n@@ -1 +1 @@\n-v1\n+v2\nchanged\n", result.out
    assert_equal "", result.err
  end
end
