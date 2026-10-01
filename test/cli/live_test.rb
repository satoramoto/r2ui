# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require_relative "../../conformance/lib/vt"

class CLILiveTest < Minitest::Test
  include R2UI::CLI::Testing

  Live = R2UI::CLI::Live

  def screen(out, cols: 80, rows: 20)
    vt = Conformance::VT.new(cols:, rows:)
    vt.feed(out)
    vt
  end

  def text(vt) = vt.lines.map(&:rstrip).reject(&:empty?)

  # ---- off a live terminal ----

  def test_off_a_terminal_run_just_yields
    s = test_shell
    live = Live.new(s) { "drawing" }
    refute live.live?
    value = live.run { |l| assert_same live, l; :done }
    assert_equal :done, value
    refute live.running?
    assert_equal "", s.output.string
    assert_nil s.live
  end

  def test_term_dumb_draws_nothing
    s = test_shell(tty: true, env: { "TERM" => "dumb" })
    Live.new(s) { "drawing" }.run { s.puts "plain" }
    assert_equal "plain\n", s.output.string
  end

  def test_needs_a_view
    assert_raises(ArgumentError) { Live.new(test_shell) }
  end

  # ---- on a terminal ----

  def test_hides_the_cursor_then_shows_it_and_the_final_frame_stays
    s = test_shell(tty: true)
    state = "working"
    live = Live.new(s) { "Status: #{state}" }
    live.run do
      assert live.running?
      assert_same live, s.live
      state = "finished"
    end
    refute live.running?
    assert_nil s.live

    out = s.output.string
    assert out.start_with?(Live::HIDE_CURSOR)
    assert out.end_with?(Live::SHOW_CURSOR)
    vt = screen(out)
    assert vt.cursor_visible?
    assert_equal ["Status: finished"], text(vt)
  end

  def test_run_returns_the_block_value
    s = test_shell(tty: true)
    assert_equal 42, Live.new(s) { "x" }.run { 42 }
  end

  def test_multi_line_final_frame
    s = test_shell(tty: true)
    Live.new(s) { "one\ntwo\nthree" }.run { nil }
    assert_equal %w[one two three], text(screen(s.output.string))
  end

  def test_println_puts_a_line_above_the_region
    s = test_shell(tty: true)
    count = 0
    live = Live.new(s) { "count #{count}" }
    live.run do
      count = 1
      live.println("first note")
      count = 2
      s.puts("second note")
    end
    assert_equal ["first note", "second note", "count 2"], text(screen(s.output.string))
  end

  def test_println_off_a_terminal_writes_a_plain_line
    s = test_shell
    Live.new(s) { "x" }.println("hello")
    assert_equal "hello\n", s.output.string
  end

  def test_cursor_is_shown_again_when_the_block_raises
    s = test_shell(tty: true)
    live = Live.new(s) { "busy" }
    assert_raises(RuntimeError) { live.run { raise "boom" } }
    refute live.running?
    assert_nil s.live
    out = s.output.string
    assert out.end_with?(Live::SHOW_CURSOR)
    vt = screen(out)
    assert vt.cursor_visible?
    assert_equal ["busy"], text(vt)
  end

  def test_cursor_is_shown_again_on_interrupt
    s = test_shell(tty: true)
    assert_raises(Interrupt) { Live.new(s) { "busy" }.run { raise Interrupt } }
    assert screen(s.output.string).cursor_visible?
  end

  def test_clear_erases_the_region_instead_of_leaving_it
    s = test_shell(tty: true)
    s.puts "before"
    live = Live.new(s) { "one\ntwo" }
    live.run { live.clear = true }
    vt = screen(s.output.string)
    assert_equal ["before"], text(vt)
    assert vt.cursor_visible?
    assert_equal [1, 0], vt.cursor

    s = test_shell(tty: true)
    Live.new(s, clear: true) { "gone" }.run { nil }
    assert_empty text(screen(s.output.string))
  end

  def test_a_view_that_raises_on_the_ticker_is_raised_from_run_with_the_cursor_restored
    s = test_shell(tty: true)
    calls = 0
    live = Live.new(s, fps: 200) do
      calls += 1
      raise ArgumentError, "bad view" if calls > 1

      "ok"
    end
    error = assert_raises(ArgumentError) { live.run { sleep 0.05 } }
    assert_equal "bad view", error.message
    refute live.running?
    assert_nil s.live
    assert screen(s.output.string).cursor_visible?
  end

  def test_stop_restores_the_cursor_when_the_last_draw_raises
    s = test_shell(tty: true)
    fail_now = false
    live = Live.new(s, fps: 1) { fail_now ? raise("last frame") : "ok" }
    assert_raises(RuntimeError) { live.run { fail_now = true } }
    refute live.running?
    assert_nil s.live
    assert s.output.string.end_with?(Live::SHOW_CURSOR)
  end

  def test_refresh_redraws_now
    s = test_shell(tty: true)
    label = "before"
    live = Live.new(s, fps: 1) { label }
    live.run do
      assert_equal ["before"], text(screen(s.output.string))
      label = "after"
      live.refresh
      assert_equal ["after"], text(screen(s.output.string))
    end
  end

  def test_frames_tick
    s = test_shell(tty: true)
    frames = []
    live = Live.new(s, fps: 100) { |frame| frames << frame; Live.spinner(frame) }
    live.run { sleep 0.05 }
    assert_operator frames.max, :>, 0
    assert_operator live.frame, :>, 0
  end

  def test_spinner_frames_cycle
    size = Live::SPINNER.size
    assert_equal "⠋", Live.spinner(0)
    assert_equal "⠙", Live.spinner(1)
    assert_equal Live.spinner(0), Live.spinner(size)
    assert_equal Live.spinner(3), Live.spinner(size + 3)
    assert_equal size, (0...size).map { |i| Live.spinner(i) }.uniq.size
  end
end
