# frozen_string_literal: true

require "test_helper"
require "r2ui/compat/bubbletea/input"
require "r2ui/compat/bubbletea/messages"

# Expected values come from bubbletea 0.1.4's go/keys.go (ParseInput and
# json.Marshal of its event structs), not from the Ruby port.
class CompatTeaInputTest < Minitest::Test
  Input = R2UI::Compat::Tea::Input

  def key(key_type, runes, alt, name)
    { "type" => "key", "key_type" => key_type, "runes" => runes, "alt" => alt, "name" => name }
  end

  def mouse(x, y, button, action, shift: false, alt: false, ctrl: false)
    { "type" => "mouse", "x" => x, "y" => y, "button" => button, "action" => action,
      "shift" => shift, "alt" => alt, "ctrl" => ctrl }
  end

  # --- key names (keyNames / tea_get_key_name) ---

  def test_key_names
    assert_predicate Input::KEY_NAMES, :frozen?
    assert_equal 54, Input::KEY_NAMES.size
    assert_equal "ctrl+@", Input.key_name(0)
    assert_equal "tab", Input.key_name(9)
    assert_equal "enter", Input.key_name(13)
    assert_equal "esc", Input.key_name(27)
    assert_equal "backspace", Input.key_name(127)
    assert_equal "runes", Input.key_name(-1)
    assert_equal "shift+tab", Input.key_name(-24)
    assert_equal "space", Input.key_name(-25)
    assert_equal "f12", Input.key_name(-23)
    assert_equal "", Input.key_name(28)
    assert_equal "", Input.key_name(-100)
    assert_equal "", Input.key_name(-26)
  end

  # --- control characters ---

  CONTROL = {
    0 => "ctrl+@", 1 => "ctrl+a", 2 => "ctrl+b", 3 => "ctrl+c", 4 => "ctrl+d", 5 => "ctrl+e",
    6 => "ctrl+f", 7 => "ctrl+g", 8 => "ctrl+h", 9 => "tab", 10 => "ctrl+j", 11 => "ctrl+k",
    12 => "ctrl+l", 13 => "enter", 14 => "ctrl+n", 15 => "ctrl+o", 16 => "ctrl+p", 17 => "ctrl+q",
    18 => "ctrl+r", 19 => "ctrl+s", 20 => "ctrl+t", 21 => "ctrl+u", 22 => "ctrl+v", 23 => "ctrl+w",
    24 => "ctrl+x", 25 => "ctrl+y", 26 => "ctrl+z", 28 => "ctrl+?", 29 => "ctrl+?",
    30 => "ctrl+?", 31 => "ctrl+?", 127 => "backspace"
  }.freeze

  def test_each_control_char
    CONTROL.each do |byte, name|
      assert_equal [1, key(byte, nil, false, name)], Input.parse(byte.chr), "byte #{byte}"
    end
  end

  def test_control_char_consumes_one_byte
    assert_equal [1, key(3, nil, false, "ctrl+c")], Input.parse("\x03abc")
  end

  # --- escape sequences ---

  SEQUENCES = {
    "\e[A" => [-2, "up"], "\e[B" => [-3, "down"], "\e[C" => [-4, "right"], "\e[D" => [-5, "left"],
    "\e[H" => [-6, "home"], "\e[F" => [-7, "end"], "\e[1~" => [-6, "home"], "\e[4~" => [-7, "end"],
    "\e[5~" => [-8, "pgup"], "\e[6~" => [-9, "pgdown"], "\e[2~" => [-11, "insert"],
    "\e[3~" => [-10, "delete"],
    "\eOP" => [-12, "f1"], "\eOQ" => [-13, "f2"], "\eOR" => [-14, "f3"], "\eOS" => [-15, "f4"],
    "\e[15~" => [-16, "f5"], "\e[17~" => [-17, "f6"], "\e[18~" => [-18, "f7"],
    "\e[19~" => [-19, "f8"], "\e[20~" => [-20, "f9"], "\e[21~" => [-21, "f10"],
    "\e[23~" => [-22, "f11"], "\e[24~" => [-23, "f12"], "\e[Z" => [-24, "shift+tab"],
    "\e[1;2A" => [-100, "unknown"], "\e[1;2B" => [-101, "unknown"],
    "\e[1;2C" => [-102, "unknown"], "\e[1;2D" => [-103, "unknown"],
    "\e[1;5A" => [-104, "unknown"], "\e[1;5B" => [-105, "unknown"],
    "\e[1;5C" => [-106, "unknown"], "\e[1;5D" => [-107, "unknown"]
  }.freeze

  def test_each_escape_sequence
    SEQUENCES.each do |seq, (type, name)|
      assert_equal [seq.bytesize, key(type, nil, false, name)], Input.parse(seq), seq.inspect
      assert_equal [seq.bytesize, key(type, nil, false, name)], Input.parse("#{seq}xyz"), seq.inspect
    end
  end

  def test_alt_combos
    assert_equal [2, key(-1, [97], true, "alt+a")], Input.parse("\ea")
    assert_equal [2, key(-1, [32], true, "alt+ ")], Input.parse("\e ")
    assert_equal [2, key(-1, [126], true, "alt+~")], Input.parse("\e~")
    # Unknown CSI: ESC [ is alt+[ (the rest is parsed later as runes).
    assert_equal [2, key(-1, [91], true, "alt+[")], Input.parse("\e[X")
    # F1 prefix without final byte: alt+O.
    assert_equal [2, key(-1, [79], true, "alt+O")], Input.parse("\eO")
  end

  def test_lone_esc_and_esc_before_non_printable
    assert_equal [1, key(27, nil, false, "esc")], Input.parse("\e")
    assert_equal [1, key(27, nil, false, "esc")], Input.parse("\e\x7f")
    assert_equal [1, key(27, nil, false, "esc")], Input.parse("\e\x01")
    assert_equal [1, key(27, nil, false, "esc")], Input.parse("\e\xC3\xA9".b)
    assert_equal [1, key(27, nil, false, "esc")], Input.parse("\e\e")
  end

  # --- printable / UTF-8 ---

  def test_space
    assert_equal [1, key(-25, [32], false, "space")], Input.parse(" ")
  end

  def test_ascii_and_multibyte
    assert_equal [1, key(-1, [113], false, "q")], Input.parse("q")
    assert_equal [1, key(-1, [65], false, "A")], Input.parse("AB")
    assert_equal [2, key(-1, [0xe9], false, "é")], Input.parse("é")
    assert_equal [3, key(-1, [0x20ac], false, "€")], Input.parse("€x")
    assert_equal [4, key(-1, [0x1f600], false, "😀")], Input.parse("😀")
    # A valid encoding of U+FFFD is a real rune in Go (size 3).
    assert_equal [3, key(-1, [0xfffd], false, "\u{fffd}")], Input.parse("\u{fffd}")
  end

  def test_invalid_utf8_skips_one_byte
    assert_equal [1, nil], Input.parse("\xff".b)
    assert_equal [1, nil], Input.parse("\x80abc".b)
    assert_equal [1, nil], Input.parse("\xE2\x82".b)       # truncated
    assert_equal [1, nil], Input.parse("\xC0\xAF".b)       # overlong
    assert_equal [1, nil], Input.parse("\xED\xA0\x80".b)   # surrogate
    assert_equal [1, nil], Input.parse("\xF4\x90\x80\x80".b) # > U+10FFFF
  end

  def test_empty
    assert_equal [0, nil], Input.parse("")
  end

  # --- focus ---

  def test_focus_and_blur
    assert_equal [3, { "type" => "focus", "focus" => true }], Input.parse("\e[I")
    assert_equal [3, { "type" => "blur", "focus" => false }], Input.parse("\e[Oabc")
  end

  # --- SGR mouse ---

  def test_mouse_press_release_motion
    assert_equal [10, mouse(9, 4, 0, 0)], Input.parse("\e[<0;10;5M")
    assert_equal [10, mouse(9, 4, 0, 1)], Input.parse("\e[<0;10;5m")
    assert_equal [9, mouse(0, 0, 2, 0)], Input.parse("\e[<2;1;1Mzz")
    assert_equal [10, mouse(2, 3, 0, 2)], Input.parse("\e[<32;3;4M")
    # Release wins over motion bit.
    assert_equal [10, mouse(2, 3, 0, 1)], Input.parse("\e[<32;3;4m")
    # Motion with no button held: 35 = 32|3.
    assert_equal [10, mouse(2, 3, 3, 2)], Input.parse("\e[<35;3;4M")
  end

  def test_mouse_wheel
    assert_equal [12, mouse(19, 9, 4, 0)], Input.parse("\e[<64;20;10M")
    assert_equal [12, mouse(19, 9, 5, 0)], Input.parse("\e[<65;20;10M")
    # 66/67: button_num 2/3 stays unchanged.
    assert_equal [12, mouse(19, 9, 2, 0)], Input.parse("\e[<66;20;10M")
  end

  def test_mouse_modifiers
    assert_equal [9, mouse(0, 0, 0, 0, shift: true)], Input.parse("\e[<4;1;1M")
    assert_equal [9, mouse(0, 0, 1, 0, alt: true)], Input.parse("\e[<9;1;1M")
    assert_equal [10, mouse(0, 0, 0, 0, ctrl: true)], Input.parse("\e[<16;1;1M")
    assert_equal [10, mouse(0, 0, 5, 0, shift: true, alt: true, ctrl: true)], Input.parse("\e[<93;1;1M")
  end

  def test_mouse_zero_coords_go_negative
    assert_equal [9, mouse(-1, -1, 0, 0)], Input.parse("\e[<0;0;0M")
  end

  def test_mouse_extra_params_ignored
    assert_equal [11, mouse(1, 2, 0, 0)], Input.parse("\e[<0;2;3;9M")
  end

  def test_mouse_malformed_falls_back_to_alt_bracket
    alt_bracket = [2, key(-1, [91], true, "alt+[")]
    assert_equal alt_bracket, Input.parse("\e[<0;1M")        # two params
    assert_equal alt_bracket, Input.parse("\e[<0;;1;2M")     # empty field skipped
    assert_equal alt_bracket, Input.parse("\e[<a;1;1M")      # non-digit
    assert_equal alt_bracket, Input.parse("\e[<0;1;1")       # no terminator
    assert_equal alt_bracket, Input.parse("\e[<#{'1' * 30}M") # terminator beyond index 31
    assert_equal alt_bracket, Input.parse("\e[<1M")          # shorter than 6 bytes
  end

  # --- parse_all ---

  def test_parse_all_multi_event_chunk
    events = Input.parse_all("ab\e[A\x03\e[<0;1;1M\xff \e".b)
    assert_equal [
      key(-1, [97], false, "a"),
      key(-1, [98], false, "b"),
      key(-2, nil, false, "up"),
      key(3, nil, false, "ctrl+c"),
      mouse(0, 0, 0, 0),
      key(-25, [32], false, "space"),
      key(27, nil, false, "esc")
    ], events
  end

  def test_parse_all_unknown_csi_splits
    assert_equal [key(-1, [91], true, "alt+["), key(-1, [88], false, "X")], Input.parse_all("\e[X")
  end

  def test_parse_all_empty
    assert_equal [], Input.parse_all("")
  end

  def test_paste
    paste = { "type" => "key", "key_type" => -1, "runes" => "hi q€".codepoints, "alt" => false,
              "name" => "[hi q€]", "paste" => true }
    assert_equal [key(-1, [120], false, "x"), paste, key(-1, [121], false, "y")],
                 Input.parse_all("x\e[200~hi q€\e[201~y".b)
  end

  def test_paste_keeps_control_and_escape_bytes_as_text
    events = Input.parse_all("\e[200~a\r\e[Ab\e[201~")
    assert_equal 1, events.size
    assert_equal "a\r\e[Ab".codepoints, events[0]["runes"]
  end

  def test_paste_without_end_marker_takes_rest
    events = Input.parse_all("\e[200~abc")
    assert_equal [{ "type" => "key", "key_type" => -1, "runes" => [97, 98, 99], "alt" => false,
                    "name" => "[abc]", "paste" => true }], events
  end

  def test_empty_paste
    events = Input.parse_all("\e[200~\e[201~q")
    assert_equal [{ "type" => "key", "key_type" => -1, "runes" => [], "alt" => false, "name" => "[]",
                    "paste" => true }, key(-1, [113], false, "q")], events
  end

  # --- Decoder: a paste spread over several reads (issue #4) ---

  def feed_all(*chunks)
    decoder = Input::Decoder.new
    chunks.flat_map { |chunk| decoder.feed(chunk) }
  end

  def test_decoder_long_paste_over_many_reads
    text = "line one\r#{'x' * 600}\rlast"
    bytes = "a\e[200~#{text}\e[201~b".b
    chunks = bytes.chars.each_slice(256).map(&:join)
    events = feed_all(*chunks)
    assert_equal [key(-1, [97], false, "a"), Input.paste_event(text.b), key(-1, [98], false, "b")], events
  end

  def test_decoder_holds_open_paste_until_end_marker
    decoder = Input::Decoder.new
    assert_equal [], decoder.feed("\e[200~ab")
    assert_equal [], decoder.feed("c\e[20")
    assert_equal [Input.paste_event("abc"), key(-1, [113], false, "q")], decoder.feed("1~q")
  end

  def test_decoder_start_marker_split_across_reads
    ["\e[2", "\e[20", "\e[200"].each do |head|
      tail = "\e[200~"[head.size..]
      assert_equal [key(-1, [120], false, "x"), Input.paste_event("hi")],
                   feed_all("x#{head}", "#{tail}hi\e[201~"), head.inspect
    end
  end

  def test_decoder_does_not_hold_esc_or_alt_bracket
    decoder = Input::Decoder.new
    assert_equal [key(27, nil, false, "esc")], decoder.feed("\e")
    assert_equal [key(-1, [91], true, "alt+[")], decoder.feed("\e[")
  end

  def test_decoder_held_prefix_that_is_not_a_paste_decodes_as_keys
    assert_equal [key(-11, nil, false, "insert")], feed_all("\e[2", "~")
  end

  def test_decoder_flush_emits_held_bytes
    decoder = Input::Decoder.new
    decoder.feed("\e[200~abc")
    assert_equal [Input.paste_event("abc")], decoder.flush
    assert_equal [], decoder.flush
  end

  # --- through Bubbletea.parse_event ---

  def tea_message(bytes)
    Bubbletea.parse_event(Input.parse(bytes)[1])
  end

  def test_parse_event_keys
    { "q" => "q", " " => "space", "\x03" => "ctrl+c", "\r" => "enter", "\x7f" => "backspace",
      "\e" => "esc", "\ea" => "alt+a", "\e[A" => "up", "\e[Z" => "shift+tab", "\e[24~" => "f12",
      "\e[1;5C" => "unknown", "é" => "é", "\x1c" => "ctrl+?" }.each do |bytes, name|
      msg = tea_message(bytes)
      assert_instance_of Bubbletea::KeyMessage, msg
      assert_equal name, msg.to_s, bytes.inspect
    end
  end

  def test_parse_event_key_predicates
    assert_predicate tea_message(" "), :space?
    assert_equal " ", tea_message(" ").char
    assert_predicate tea_message("\ea"), :runes?
    assert tea_message("\ea").alt
    assert_predicate tea_message("\e[B"), :down?
    assert_equal [], tea_message("\e[B").runes
    assert_predicate tea_message("\x03"), :ctrl?
  end

  def test_parse_event_mouse
    msg = tea_message("\e[<65;20;10M")
    assert_instance_of Bubbletea::MouseMessage, msg
    assert_equal [19, 9, 5, 0], [msg.x, msg.y, msg.button, msg.action]
    assert_predicate msg, :wheel?
    assert_predicate msg, :press?
    rel = tea_message("\e[<22;3;4m")
    assert_predicate rel, :release?
    assert_predicate rel, :middle?
    assert rel.shift
    assert rel.ctrl
    refute rel.alt
  end

  def test_parse_event_focus_blur
    assert_instance_of Bubbletea::FocusMessage, tea_message("\e[I")
    assert_instance_of Bubbletea::BlurMessage, tea_message("\e[O")
  end

  def test_parse_event_paste
    msg = Bubbletea.parse_event(Input.parse_all("\e[200~q\e[201~")[0])
    assert_equal "[q]", msg.to_s
    assert_equal "q", msg.char
  end
end
