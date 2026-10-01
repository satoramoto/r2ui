# frozen_string_literal: true

require "test_helper"
require_relative "../../conformance/lib/vt"

class VTTest < Minitest::Test
  def vt(input = "", cols: 10, rows: 4)
    t = Conformance::VT.new(cols: cols, rows: rows)
    t.feed(input)
    t
  end

  # ---- text, C0, wrapping ----

  def test_plain_text_and_cursor
    t = vt("hello")
    assert_equal ["hello", "", "", ""], t.lines
    assert_equal [0, 5], t.cursor
  end

  def test_lf_does_not_imply_cr
    t = vt("ab\ncd\r\nef")
    assert_equal ["ab", "  cd", "ef", ""], t.lines
  end

  def test_vt_ff_act_like_lf_and_bel_is_ignored
    assert_equal ["a", " b", "  c", ""], vt("a\vb\fc\a").lines
  end

  def test_backspace_and_tab
    assert_equal ["aXc"], vt("abc\b\bX", rows: 1).lines
    t = vt("a\tb", cols: 20, rows: 1)
    assert_equal ["a       b"], t.lines
    t = vt("\t\t\t", rows: 1)
    assert_equal [0, 9], t.cursor
  end

  def test_pending_wrap
    t = vt("0123456789")
    assert_equal [0, 9], t.cursor
    assert_equal ["0123456789", "", "", ""], t.lines
    t.feed("X")
    assert_equal ["0123456789", "X", "", ""], t.lines
  end

  def test_cr_cancels_pending_wrap
    t = vt("0123456789\rX")
    assert_equal ["X123456789", "", "", ""], t.lines
  end

  def test_autowrap_off_overwrites_last_column
    t = vt("\e[?7l0123456789AB")
    assert_equal ["012345678B", "", "", ""], t.lines
  end

  def test_wrap_at_bottom_scrolls
    t = vt("0123456789abcdefghijklmnopqrstuvwxyz0123X", rows: 4)
    assert_equal ["abcdefghij", "klmnopqrst", "uvwxyz0123", "X"], t.lines
  end

  # ---- UTF-8 and wide chars ----

  def test_utf8_split_across_feeds
    t = vt
    bytes = "é→".b
    bytes.each_char { |b| t.feed(b) }
    assert_equal "é→", t.lines[0]
    assert_equal [0, 2], t.cursor
  end

  def test_invalid_utf8_becomes_replacement_char
    assert_equal "a�b", vt("a\xFFb".b).lines[0]
  end

  def test_wide_chars_take_two_cells
    t = vt("日本x")
    assert_equal "日本x", t.lines[0]
    assert_equal [0, 5], t.cursor
    t = vt("🙂a")
    assert_equal [0, 3], t.cursor
  end

  def test_wide_char_wraps_when_one_column_left
    t = vt("012345678日")
    assert_equal ["012345678", "日", "", ""], t.lines
  end

  def test_overwriting_half_a_wide_char_blanks_the_other_half
    assert_equal " x", vt("日\e[2Gx").lines[0]
    assert_equal "x", vt("日\e[1Gx").lines[0]
  end

  def test_combining_mark_joins_previous_cell
    t = vt("éx")
    assert_equal "éx", t.lines[0]
    assert_equal [0, 2], t.cursor
  end

  # ---- CSI cursor movement ----

  def test_cursor_movement_and_clamping
    t = vt("\e[3;4H")
    assert_equal [2, 3], t.cursor
    t.feed("\e[A\e[2C")
    assert_equal [1, 5], t.cursor
    t.feed("\e[99B\e[99D")
    assert_equal [3, 0], t.cursor
    t.feed("\e[99;99f")
    assert_equal [3, 9], t.cursor
    t.feed("\e[2F")
    assert_equal [1, 0], t.cursor
    t.feed("\e[E\e[5G")
    assert_equal [2, 4], t.cursor
    t.feed("\e[1d\e[3`")
    assert_equal [0, 2], t.cursor
    t.feed("\e[H")
    assert_equal [0, 0], t.cursor
  end

  # ---- erasing / editing ----

  def test_erase_display
    full = "abcdefghij" * 3 + "abcdefghi"
    assert_equal ["abcdefghij", "abcd", "", ""], vt("#{full}\e[2;5H\e[J").lines
    assert_equal ["", "     fghij", "abcdefghij", "abcdefghi"], vt("#{full}\e[2;5H\e[1J").lines
    assert_equal ["", "", "", ""], vt("#{full}\e[2J").lines
    assert_equal [3, 9], vt("#{full}\e[2J").cursor
  end

  def test_erase_line_and_chars
    assert_equal ["abc"], vt("abcdef\e[4G\e[K", rows: 1).lines
    assert_equal ["    ef"], vt("abcdef\e[4G\e[1K", rows: 1).lines
    assert_equal [""], vt("abcdef\e[2K", rows: 1).lines
    assert_equal ["a  def"], vt("abcdef\e[2G\e[2X", rows: 1).lines
  end

  def test_insert_and_delete_chars
    assert_equal ["ab  cdefgh"], vt("abcdefghij\e[3G\e[2@", rows: 1).lines
    assert_equal ["abefghij"], vt("abcdefghij\e[3G\e[2P", rows: 1).lines
  end

  def test_insert_and_delete_lines
    t = vt("1\r\n2\r\n3\r\n4\e[2H\e[L")
    assert_equal ["1", "", "2", "3"], t.lines
    t = vt("1\r\n2\r\n3\r\n4\e[2H\e[2M")
    assert_equal ["1", "4", "", ""], t.lines
  end

  def test_scroll_up_and_down
    assert_equal ["3", "4", "", ""], vt("1\r\n2\r\n3\r\n4\e[2S").lines
    assert_equal ["", "1", "2", "3"], vt("1\r\n2\r\n3\r\n4\e[T").lines
  end

  def test_scroll_region
    t = vt("1\r\n2\r\n3\r\n4\e[2;3r")
    assert_equal [0, 0], t.cursor
    t.feed("\e[3H\nX")
    assert_equal ["1", "3", "X", "4"], t.lines
    t.feed("\e[2H\eMY")
    assert_equal ["1", "Y", "3", "4"], t.lines
  end

  def test_index_nel_and_reverse_index_at_top
    t = vt("ab\eDc\eEd")
    assert_equal ["ab", "  c", "d", ""], t.lines
    t = vt("1\r\n2\e[H\eMX")
    assert_equal ["X", "1", "2", ""], t.lines
  end

  def test_erase_and_scroll_fill_with_current_background
    t = vt("\e[44m\e[2K\e[0m", rows: 2)
    assert_equal [[0, 0, 9, "bg=4"]], t.style_runs
    t = vt("\e[41m\e[2H\n", rows: 2)
    assert_equal [[1, 0, 9, "bg=1"]], t.style_runs
  end

  def test_rep_repeats_last_char
    assert_equal ["ab---"], vt("ab-\e[2b", rows: 1).lines
  end

  # ---- SGR ----

  def test_sgr_attributes_in_fixed_order
    t = vt("\e[9;7;4;1;3;2;5;8mX")
    assert_equal [[0, 0, 0, "bold faint italic underline blink reverse invisible strike"]], t.style_runs
  end

  def test_sgr_resets
    t = vt("\e[1;2;3;4;5;7;8;9;31;42mA\e[22;23;24;25;27;28;29;39;49mB\e[1mC\e[mD")
    assert_equal [[0, 0, 0, "bold faint italic underline blink reverse invisible strike fg=1 bg=2"],
                  [0, 2, 2, "bold"]], t.style_runs
  end

  def test_sgr_colors
    t = vt("\e[31mA\e[91mB\e[38;5;200mC\e[38;2;255;128;0mD\e[0;102mE\e[48:2::1:2:3mF\e[0;38:2:1:2:3mG\e[0;38:5:9mH")
    assert_equal [[0, 0, 0, "fg=1"], [0, 1, 1, "fg=9"], [0, 2, 2, "fg=200"], [0, 3, 3, "fg=#ff8000"],
                  [0, 4, 4, "bg=10"], [0, 5, 5, "bg=#010203"],
                  [0, 6, 6, "fg=#010203"], [0, 7, 7, "fg=9"]], t.style_runs
  end

  def test_underline_styles_and_double_underline
    assert_equal [[0, 0, 0, "underline"]], vt("\e[4:3mX").style_runs
    assert_equal [], vt("\e[4m\e[4:0mX").style_runs
    assert_equal [[0, 0, 0, "underline"]], vt("\e[21mX").style_runs
  end

  def test_underline_color_and_unknown_codes_are_ignored
    t = vt("\e[58;2;1;2;3;1m\e[58:5:3;73mX")
    assert_equal [[0, 0, 0, "bold"]], t.style_runs
  end

  def test_styled_blanks_count_in_runs
    t = vt("\e[7m  \e[m x")
    assert_equal ["   x"], t.lines.take(1)
    assert_equal [[0, 0, 1, "reverse"]], t.style_runs
  end

  def test_wide_char_style_covers_both_cells
    assert_equal [[0, 0, 1, "bold"]], vt("\e[1m日").style_runs
  end

  # ---- save/restore, modes, alt screen ----

  def test_save_restore_cursor_includes_sgr
    t = vt("\e[2;3H\e[1m\e7\e[m\e[HA\e8B")
    assert_equal [1, 3], t.cursor
    assert_equal [[1, 2, 2, "bold"]], t.style_runs
    t = vt("\e[3;4H\e[s\e[H\e[u")
    assert_equal [2, 3], t.cursor
  end

  def test_dec_modes
    t = vt("\e[?25l\e[?1;1000;1006;2004h\e[?1004h\e[?1l")
    refute t.cursor_visible?
    assert_equal [1000, 1004, 1006, 2004], t.modes
    t.feed("\e[?1002h")
    assert_equal [1002, 1004, 1006, 2004], t.modes # xterm: one mouse mode at a time
    t.feed("\e[?1002;1004;1006;2004l\e[?25h")
    assert_equal [], t.modes
    assert t.cursor_visible?
  end

  def test_alt_screen_1049_saves_and_restores_cursor
    t = vt("main\e[2;3H\e[?1049h")
    assert t.alt_screen?
    assert_equal ["", "", "", ""], t.lines
    t.feed("\e[Halt")
    t.feed("\e[?1049l")
    refute t.alt_screen?
    assert_equal ["main", "", "", ""], t.lines
    assert_equal [1, 2], t.cursor
  end

  def test_alt_screen_47_and_1047_do_not_restore_cursor
    t = vt("main\e[?47hX\e[?47l")
    assert_equal ["main", "", "", ""], t.lines
    assert_equal [0, 5], t.cursor # cursor stays where the alt screen left it
    t = vt("\e[?1047hab\e[?1047l\e[?47h")
    assert_equal ["", "", "", ""], t.lines # 1047 clears the alt screen on exit
  end

  def test_full_reset
    t = vt("\e[1;31mhi\e[?25l\e[?2004h\e[?1049h\e[2;3r\ec")
    assert_equal ["", "", "", ""], t.lines
    assert_equal [0, 0], t.cursor
    assert t.cursor_visible?
    refute t.alt_screen?
    assert_equal [], t.modes
    t.feed("\e[3H\nX")
    assert_equal ["", "", "", "X"], t.lines # margins reset too
  end

  def test_line_drawing_charset
    t = vt("\e(0lqk\e(Bq\x0e\x0f")
    assert_equal "┌─┐q", t.lines[0]
    t = vt("\e)0a\x0eq\x0fq")
    assert_equal "a─q", t.lines[0]
  end

  # ---- OSC, strings, replies ----

  def test_osc_title_with_bel_and_st
    assert_equal "hello", vt("\e]0;hello\a").title
    assert_equal "wörld", vt("\e]2;wörld\e\\x").title
    assert_equal "x", vt("\e]2;wörld\e\\x").lines[0]
    assert_nil vt("\e]8;;http://x\e\\").title
  end

  def test_osc_color_queries_reply_with_same_terminator
    assert_equal "\e]10;rgb:ffff/ffff/ffff\a", vt.feed("\e]10;?\a")
    assert_equal "\e]11;rgb:0000/0000/0000\e\\", vt.feed("\e]11;?\e\\")
  end

  def test_dcs_apc_pm_sos_are_swallowed
    assert_equal "ab", vt("a\eP1$r0m\e\\\e_Gi=1;AAAA\e\\\e^pm\e\\\eXsos\e\\b").lines[0]
  end

  def test_replies
    t = vt("\e[2;3H")
    assert_equal "\e[2;3R", t.feed("\e[6n")
    assert_equal "\e[0n", t.feed("\e[5n")
    assert_equal "\e[?62;22c", t.feed("\e[c")
    assert_equal "\e[?62;22c", t.feed("\e[0c")
    assert_equal "", t.feed("\e[>c")
    t.feed("\e[?2004h\e[?25l")
    assert_equal "\e[?2004;1$y", t.feed("\e[?2004$p")
    assert_equal "\e[?25;2$y", t.feed("\e[?25$p")
    assert_equal "\e[?7;1$y", t.feed("\e[?7$p")
    assert_equal "\e[?1049;2$y", t.feed("\e[?1049$p")
    assert_equal "\e[?9999;0$y", t.feed("\e[?9999$p")
    assert_equal "", t.feed("plain")
  end

  def test_unknown_sequences_are_consumed_cleanly
    t = vt("a\e[>4;1m\e[=5u\e[1 q\e[?u\e[12;34;56t\e[0%z\e=\e>\e#3\e%Gb\e[1;2:3;4zc")
    assert_equal "abc", t.lines[0]
    assert_equal "ab", vt("a\e[1\x18b").lines[0] # CAN aborts
    assert_equal ["a", " b"], vt("a\e[1;\eDb").lines.take(2) # ESC restarts the sequence
  end

  def test_controls_execute_inside_csi
    assert_equal ["a", "b"], vt("a\e[\n1Cb", rows: 2).lines.map(&:strip)
  end

  # ---- snapshot ----

  def test_snapshot_format
    t = Conformance::VT.new(cols: 12, rows: 10)
    t.feed("\e[?25l\e[?2004h\e[1;38;2;255;128;0mCount\e[m: 0\e[3;2H\e[7mx\e[m")
    expected = <<~SNAP
      alt_screen: off  cursor: hidden  modes: 2004
       1|Count: 0
       2|
       3| x
       4|
       5|
       6|
       7|
       8|
       9|
      10|
      styles:
       1:1-5 bold fg=#ff8000
       3:2-2 reverse
    SNAP
    assert_equal expected, t.snapshot
  end

  def test_snapshot_without_styles_or_modes
    assert_equal "alt_screen: on  cursor: visible  modes: -\n1|hi\nstyles: none\n",
                 vt("\e[?1049hhi", rows: 1).snapshot
  end

  # ---- the property the harness relies on ----

  def test_full_redraw_and_partial_update_give_identical_snapshots
    full = vt("\e[H\e[2J\e[1;31mTitle\e[m\r\nCount: 1\r\n\e[7m footer \e[m")
    full.feed("\e[H\e[2J\e[1;31mTitle\e[m\r\nCount: 2\r\n\e[7m footer \e[m")
    partial = vt("\e[H\e[2J\e[1;31mTitle\e[m\r\nCount: 1\r\n\e[7m footer \e[m")
    partial.feed("\e[2;8H2")
    partial.feed("\e[3;9H")
    assert_equal full.snapshot, partial.snapshot
  end

  def test_equivalent_sgr_encodings_give_identical_snapshots
    a = vt("\e[1;31mX\e[0m\e[44m \e[49mY")
    b = vt("\e[1m\e[38;5;1mX\e[22;39m\e[48:5:4m \e[mY")
    assert_equal a.snapshot, b.snapshot
  end

  def test_relative_and_absolute_moves_give_identical_snapshots
    a = vt("ab\r\n  cd\e[1;10Hz")
    b = vt("ab\e[2;3Hcd\e[A\e[99Cz")
    assert_equal a.snapshot, b.snapshot
  end
end
