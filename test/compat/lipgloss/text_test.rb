# frozen_string_literal: true

require "minitest/autorun"
$LOAD_PATH.unshift File.expand_path("../../../lib", __dir__)
require "r2ui/compat/lipgloss"

# Tests for R2UI::Compat::Gloss::Text. Two kinds of expectations, none hand-written:
# - tables ported verbatim from the upstream Go tests (x/ansi v0.8.0 width_test.go, truncate_test.go,
#   wrap_test.go and x/cellbuf wrap_test.go);
# - values recorded from the real lipgloss gem 0.2.2 (Lipgloss.width, Style#width(n).render,
#   Style#max_width(n).render) rendering without a TTY.
class TextTest < Minitest::Test
  T = R2UI::Compat::Gloss::Text

  # --- upstream: x/ansi width_test.go [name, input, stripped, width, wcwidth] ---------------------
  ANSI_WIDTH_CASES = [
    ["empty", "", "", 0, 0],
    ["ascii", "hello", "hello", 5, 5],
    ["emoji", "👋", "👋", 2, 2],
    ["wideemoji", "🫧", "🫧", 2, 2],
    ["combining", "à", "à", 1, 1],
    ["control", "\x1b[31mhello\x1b[0m", "hello", 5, 5],
    ["csi8", "\x9b38;5;1mhello\x9bm", "hello", 5, 5],
    ["osc", "\x9d2;charmbracelet: ~/Source/bubbletea\x9c", "", 0, 0],
    ["controlemoji", "\x1b[31m👋\x1b[0m", "👋", 2, 2],
    ["oscwideemoji", "\x1b]2;title👨‍👩‍👦\x07", "", 0, 0],
    ["oscwideemoji", "\x1b[31m👨‍👩‍👦\x1b[m", "👨‍👩‍👦", 2, 2],
    ["multiemojicsi", "👨‍👩‍👦\x9b38;5;1mhello\x9bm", "👨‍👩‍👦hello", 7, 7],
    ["osc8eastasianlink", "\x9d8;id=1;https://example.com/\x9c打豆豆\x9d8;id=1;\x07", "打豆豆", 6, 6],
    ["dcsarabic", "\x1bP?123$pسلام\x1b\\اهلا", "اهلا", 4, 4],
    ["newline", "hello\nworld", "hello\nworld", 10, 10],
    ["tab", "hello\tworld", "hello\tworld", 10, 10],
    ["controlnewline", "\x1b[31mhello\x1b[0m\nworld", "hello\nworld", 10, 10],
    ["style", "\x1B[38;2;249;38;114mfoo", "foo", 3, 3],
    ["unicode", "\x1b[35m“box”\x1b[0m", "“box”", 5, 5],
    ["just_unicode", "Claire’s Boutique", "Claire’s Boutique", 17, 17],
    ["unclosed_ansi", "Hey, \x1b[7m\n猴", "Hey, \n猴", 7, 7],
    ["double_asian_runes", " 你\x1b[8m好.", " 你好.", 6, 6],
    ["flag", "\u{1f1f8}\u{1f1e6}", "\u{1f1f8}\u{1f1e6}", 2, 1]
  ].freeze

  # --- upstream: x/ansi truncate_test.go [name, input, tail, width, Truncate, TruncateLeft] --------
  TRUNCATE_CASES = [
    ["empty", "", "", 0, "", ""],
    ["truncate_length_0", "foo", "", 0, "", "foo"],
    ["equalascii", "one", ".", 3, "one", ""],
    ["equalemoji", "on👋", ".", 3, "on.", ".👋"],
    ["equalcontrolemoji", "one\x1b[0m", ".", 3, "one\x1b[0m", "\x1b[0m"],
    ["truncate_tail_greater", "foo", "...", 5, "foo", ""],
    ["simple", "foobar", "", 3, "foo", "bar"],
    ["passthrough", "foobar", "", 10, "foobar", ""],
    ["ascii", "hello", "", 3, "hel", "lo"],
    ["emoji", "👋", "", 2, "👋", ""],
    ["wideemoji", "🫧", "", 2, "🫧", ""],
    ["controlemoji", "\x1b[31mhello 👋abc\x1b[0m", "", 8, "\x1b[31mhello 👋\x1b[0m", "\x1b[31mabc\x1b[0m"],
    ["osc8", "\x1b]8;;https://charm.sh\x1b\\Charmbracelet 🫧\x1b]8;;\x1b\\", "", 5,
     "\x1b]8;;https://charm.sh\x1b\\Charm\x1b]8;;\x1b\\", "\x1b]8;;https://charm.sh\x1b\\bracelet 🫧\x1b]8;;\x1b\\"],
    ["osc8_8bit", "\x9d8;;https://charm.sh\x9cCharmbracelet 🫧\x9d8;;\x9c", "", 5,
     "\x9d8;;https://charm.sh\x9cCharm\x9d8;;\x9c", "\x9d8;;https://charm.sh\x9cbracelet 🫧\x9d8;;\x9c"],
    ["style_tail", "\x1B[38;5;219mHiya!", "…", 3, "\x1B[38;5;219mHi…", "\x1B[38;5;219m…a!"],
    ["double_style_tail", "\x1B[38;5;219mHiya!\x1B[38;5;219mHello", "…", 7,
     "\x1B[38;5;219mHiya!\x1B[38;5;219mH…", "\x1B[38;5;219m\x1B[38;5;219m…llo"],
    ["noop", "\x1B[7m--", "", 2, "\x1B[7m--", "\x1b[7m"],
    ["double_width", "\x1B[38;2;249;38;114m你好\x1B[0m", "", 3,
     "\x1B[38;2;249;38;114m你\x1B[0m", "\x1B[38;2;249;38;114m好\x1B[0m"],
    ["double_width_rune", "你", "", 1, "", "你"],
    ["double_width_runes", "你好", "", 2, "你", "好"],
    ["spaces_only", "    ", "…", 2, " …", "…  "],
    ["longer_tail", "foo", "...", 2, "", "...o"],
    ["same_tail_width", "foo", "...", 3, "foo", ""],
    ["same_tail_width_control", "\x1b[31mfoo\x1b[0m", "...", 3, "\x1b[31mfoo\x1b[0m", "\x1b[31m\x1b[0m"],
    ["same_width", "foo", "", 3, "foo", ""],
    ["truncate_with_tail", "foobar", ".", 4, "foo.", ".ar"],
    ["style", "I really \x1B[38;2;249;38;114mlove\x1B[0m Go!", "", 8,
     "I really\x1B[38;2;249;38;114m\x1B[0m", " \x1B[38;2;249;38;114mlove\x1B[0m Go!"],
    ["dcs", "\x1BPq\#0;2;0;0;0\#1;2;100;100;0\#2;2;0;100;0\#1~~@@vv@@~~@@~~$\#2??}}GG}}??}}??-\#1!14@\x1B\\foobar", "…", 4,
     "\x1BPq\#0;2;0;0;0\#1;2;100;100;0\#2;2;0;100;0\#1~~@@vv@@~~@@~~$\#2??}}GG}}??}}??-\#1!14@\x1B\\foo…",
     "\x1BPq\#0;2;0;0;0\#1;2;100;100;0\#2;2;0;100;0\#1~~@@vv@@~~@@~~$\#2??}}GG}}??}}??-\#1!14@\x1B\\…ar"],
    ["emoji_tail", "\x1b[36mHello there!\x1b[m", "😃", 8, "\x1b[36mHello 😃\x1b[m", "\x1b[36m😃ere!\x1b[m"],
    ["unicode", "\x1b[35mClaire‘s Boutique\x1b[0m", "", 8, "\x1b[35mClaire‘s\x1b[0m", "\x1b[35m Boutique\x1b[0m"],
    ["wide_chars", "こんにちは", "…", 7, "こんに…", "…ちは"],
    ["style_wide_chars", "\x1b[35mこんにちは\x1b[m", "…", 7, "\x1b[35mこんに…\x1b[m", "\x1b[35m…ちは\x1b[m"],
    ["osc8_lf", "สวัสดีสวัสดี\x1b]8;;https://example.com\x1b\\\nสวัสดีสวัสดี\x1b]8;;\x1b\\", "…", 9,
     "สวัสดีสวัสดี\x1b]8;;https://example.com\x1b\\\n…\x1b]8;;\x1b\\",
     "\x1b]8;;https://example.com\x1b\\\n…วัสดีสวัสดี\x1b]8;;\x1b\\"]
  ].freeze

  # --- upstream: x/ansi truncate_test.go TestCut [desc, input, left, right, expected] -------------
  CUT_CASES = [
    ["simple string", "This is a long string", 2, 6, "is i"],
    ["with ansi", "I really \x1B[38;2;249;38;114mlove\x1B[0m Go!", 4, 25, "ally \x1b[38;2;249;38;114mlove\x1b[0m Go!"],
    ["left is 0", "Foo \x1B[38;2;249;38;114mbar\x1B[0mbaz", 0, 5, "Foo \x1B[38;2;249;38;114mb\x1B[0m"],
    ["right is 0", "\x1b[7mHello\x1b[m", 3, 0, ""],
    ["right is less than left", "\x1b[7mHello\x1b[m", 3, 2, ""],
    ["cut size is 0", "\x1b[7mHello\x1b[m", 2, 2, ""],
    ["maintains open ansi", "\x1b[38;5;212;48;5;63mHello, Artichoke!\x1b[m", 7, 16, "\x1b[38;5;212;48;5;63mArtichoke\x1b[m"]
  ].freeze

  # --- upstream: x/ansi wrap_test.go Hardwrap [name, input, limit, expected, preserveSpace] -------
  HARDWRAP_CASES = [
    ["empty string", "", 0, "", true],
    ["passthrough", "foobar\n ", 0, "foobar\n ", true],
    ["pass", "foo", 4, "foo", true],
    ["simple", "foobarfoo", 4, "foob\narfo\no", true],
    ["lf", "f\no\nobar", 3, "f\no\noba\nr", true],
    ["lf_space", "foo bar\n  baz", 3, "foo\n ba\nr\n  b\naz", true],
    ["tab", "foo\tbar", 3, "foo\n\tbar", true],
    ["unicode_space", "foo\xc2\xa0bar", 3, "foo\nbar", false],
    ["style_nochange", "\x1B[38;2;249;38;114mfoo\x1B[0m\x1B[38;2;248;248;242m \x1B[0m\x1B[38;2;230;219;116mbar\x1B[0m", 7,
     "\x1B[38;2;249;38;114mfoo\x1B[0m\x1B[38;2;248;248;242m \x1B[0m\x1B[38;2;230;219;116mbar\x1B[0m", true],
    ["style", "\x1B[38;2;249;38;114m(\x1B[0m\x1B[38;2;248;248;242mjust another test\x1B[38;2;249;38;114m)\x1B[0m", 3,
     "\x1B[38;2;249;38;114m(\x1B[0m\x1B[38;2;248;248;242mju\nst \nano\nthe\nr t\nest\x1B[38;2;249;38;114m\n)\x1B[0m", true],
    ["style_lf", "I really \x1B[38;2;249;38;114mlove\x1B[0m Go!", 8, "I really\n\x1b[38;2;249;38;114mlove\x1b[0m Go!", false],
    ["style_emoji", "I really \x1B[38;2;249;38;114mlove u🫧\x1B[0m", 8, "I really\n\x1b[38;2;249;38;114mlove u🫧\x1b[0m", false],
    ["hyperlink", "I really \x1B]8;;https://example.com/\x1B\\love\x1B]8;;\x1B\\ Go!", 10,
     "I really \x1b]8;;https://example.com/\x1b\\l\nove\x1b]8;;\x1b\\ Go!", false],
    ["dcs", "\x1BPq\#0;2;0;0;0\#1;2;100;100;0\#2;2;0;100;0\#1~~@@vv@@~~@@~~$\#2??}}GG}}??}}??-\#1!14@\x1B\\foobar", 3,
     "\x1BPq\#0;2;0;0;0\#1;2;100;100;0\#2;2;0;100;0\#1~~@@vv@@~~@@~~$\#2??}}GG}}??}}??-\#1!14@\x1B\\foo\nbar", false],
    ["begin_with_space", " foo", 4, " foo", false],
    ["style_dont_affect_wrap", "\x1B[38;2;249;38;114mfoo\x1B[0m\x1B[38;2;248;248;242m \x1B[0m\x1B[38;2;230;219;116mbar\x1B[0m", 7,
     "\x1B[38;2;249;38;114mfoo\x1B[0m\x1B[38;2;248;248;242m \x1B[0m\x1B[38;2;230;219;116mbar\x1B[0m", false],
    ["preserve_style", "\x1B[38;2;249;38;114m(\x1B[0m\x1B[38;2;248;248;242mjust another test\x1B[38;2;249;38;114m)\x1B[0m", 3,
     "\x1B[38;2;249;38;114m(\x1B[0m\x1B[38;2;248;248;242mju\nst \nano\nthe\nr t\nest\x1B[38;2;249;38;114m\n)\x1B[0m", false],
    ["emoji", "foo🫧foobar", 4, "foo\n🫧fo\nobar", false],
    ["osc8_wrap", "สวัสดีสวัสดี\x1b]8;;https://example.com\x1b\\สวัสดีสวัสดี\x1b]8;;\x1b\\", 8,
     "สวัสดีสวัสดี\x1b]8;;https://example.com\x1b\\\nสวัสดีสวัสดี\x1b]8;;\x1b\\", false],
    ["column", "VERTICAL", 1, "V\nE\nR\nT\nI\nC\nA\nL", false]
  ].freeze

  # --- upstream: x/ansi wrap_test.go Wordwrap [name, input, limit, breakpoints, expected] ---------
  WORDWRAP_CASES = [
    ["empty string", "", 0, "", ""],
    ["passthrough", "foobar\n ", 0, "", "foobar\n "],
    ["pass", "foo", 3, "", "foo"],
    ["toolong", "foobarfoo", 4, "", "foobarfoo"],
    ["white space", "foo bar foo", 4, "", "foo\nbar\nfoo"],
    ["broken_at_spaces", "foo bars foobars", 4, "", "foo\nbars\nfoobars"],
    ["hyphen", "foo-foobar", 4, "-", "foo-\nfoobar"],
    ["emoji_breakpoint", "foo😃 foobar", 4, "😃", "foo😃\nfoobar"],
    ["wide_emoji_breakpoint", "foo🫧 foobar", 4, "🫧", "foo🫧\nfoobar"],
    ["space_breakpoint", "foo --bar", 9, "-", "foo --bar"],
    ["simple", "foo bars foobars", 4, "", "foo\nbars\nfoobars"],
    ["limit", "foo bar", 5, "", "foo\nbar"],
    ["remove white spaces", "foo    \nb   ar   ", 4, "", "foo\nb\nar"],
    ["white space trail width", "foo\nb\t a\n bar", 4, "", "foo\nb\t a\n bar"],
    ["explicit_line_break", "foo bar foo\n", 4, "", "foo\nbar\nfoo\n"],
    ["explicit_breaks", "\nfoo bar\n\n\nfoo\n", 4, "", "\nfoo\nbar\n\n\nfoo\n"],
    ["example", " This is a list: \n\n\t* foo\n\t* bar\n\n\n\t* foo  \nbar    ", 6, "",
     " This\nis a\nlist: \n\n\t* foo\n\t* bar\n\n\n\t* foo\nbar"],
    ["style_code_dont_affect_length", "\x1B[38;2;249;38;114mfoo\x1B[0m\x1B[38;2;248;248;242m \x1B[0m\x1B[38;2;230;219;116mbar\x1B[0m", 7, "",
     "\x1B[38;2;249;38;114mfoo\x1B[0m\x1B[38;2;248;248;242m \x1B[0m\x1B[38;2;230;219;116mbar\x1B[0m"],
    ["style_code_dont_get_wrapped", "\x1B[38;2;249;38;114m(\x1B[0m\x1B[38;2;248;248;242mjust another test\x1B[38;2;249;38;114m)\x1B[0m", 3, "",
     "\x1B[38;2;249;38;114m(\x1B[0m\x1B[38;2;248;248;242mjust\nanother\ntest\x1B[38;2;249;38;114m)\x1B[0m"],
    ["osc8_wrap", "สวัสดีสวัสดี\x1b]8;;https://example.com\x1b\\ สวัสดีสวัสดี\x1b]8;;\x1b\\", 8, "",
     "สวัสดีสวัสดี\x1b]8;;https://example.com\x1b\\\nสวัสดีสวัสดี\x1b]8;;\x1b\\"]
  ].freeze

  # Cases shared (with different expectations) by x/ansi Wrap and cellbuf Wrap: [name, input, width].
  WRAP_INPUTS = [
    ["simple", "I really \x1B[38;2;249;38;114mlove\x1B[0m Go!", 8],
    ["passthrough", "hello world", 11],
    ["asian", "こんにち", 7],
    ["emoji", "😃👰\u{1f3fb}‍♀️🫧", 2],
    ["long style", "\x1B[38;2;249;38;114ma really long string\x1B[0m", 10],
    ["long style nbsp", "\x1B[38;2;249;38;114ma really long string\x1B[0m", 10],
    ["longer", "the quick brown foxxxxxxxxxxxxxxxx jumped over the lazy dog.", 16],
    ["longer asian", "猴 猴 猴猴 猴猴猴猴猴猴猴猴猴 猴猴猴 猴猴 猴’ 猴猴 猴.", 16],
    ["long input", "Rotated keys for a-good-offensive-cheat-code-incorporated/animal-like-law-on-the-rocks.", 76],
    ["long input2", "Rotated keys for a-good-offensive-cheat-code-incorporated/crypto-line-operating-system.", 76],
    ["hyphen breakpoint", "a-good-offensive-cheat-code", 10],
    ["extra space", "foo ", 3],
    ["extra space style", "\x1b[mfoo \x1b[m", 3],
    ["paragraph with styles",
     "Lorem ipsum dolor \x1b[1msit\x1b[m amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et " \
     "dolore magna aliqua. \x1b[31mUt enim\x1b[m ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea " \
     "\x1b[38;5;200mcommodo consequat\x1b[m. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu " \
     "fugiat nulla pariatur. \x1b[1;2;33mExcepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt " \
     "mollit anim id est laborum.\x1b[m", 30],
    ["hyphen break", "foo-bar", 5],
    ["double space", "f  bar foobaz", 6],
    ["passthrough", "foobar\n ", 0],
    ["pass", "foo", 3],
    ["toolong", "foobarfoo", 4],
    ["white space", "foo bar foo", 4],
    ["broken_at_spaces", "foo bars foobars", 4],
    ["hyphen", "foob-foobar", 4],
    ["wide_emoji_breakpoint", "foo🫧 foobar", 4],
    ["space_breakpoint", "foo --bar", 9],
    ["limit", "foo bar", 5],
    ["remove white spaces", "foo    \nb   ar   ", 4],
    ["white space trail width", "foo\nb\t a\n bar", 4],
    ["explicit_line_break", "foo bar foo\n", 4],
    ["explicit_breaks", "\nfoo bar\n\n\nfoo\n", 4],
    ["example", " This is a list: \n\n\t* foo\n\t* bar\n\n\n\t* foo  \nbar    ", 6],
    ["style_code_dont_affect_length", "\x1B[38;2;249;38;114mfoo\x1B[0m\x1B[38;2;248;248;242m \x1B[0m\x1B[38;2;230;219;116mbar\x1B[0m", 7],
    ["style_code_dont_get_wrapped", "\x1B[38;2;249;38;114m(\x1B[0m\x1B[38;2;248;248;242mjust another test\x1B[38;2;249;38;114m)\x1B[0m", 7],
    ["osc8_wrap", "สวัสดีสวัสดี\x1b]8;;https://example.com\x1b\\ สวัสดีสวัสดี\x1b]8;;\x1b\\", 8],
    ["tab", "foo\tbar", 3]
  ].freeze

  # --- upstream: x/ansi wrap_test.go TestWrap expectations, by WRAP_INPUTS index ------------------
  ANSI_WRAP_EXPECTED = [
    "I really\n\x1B[38;2;249;38;114mlove\x1B[0m Go!",
    "hello world",
    "こんに\nち",
    "😃\n👰\u{1f3fb}‍♀️\n🫧",
    "\x1B[38;2;249;38;114ma really\nlong\nstring\x1B[0m",
    "\x1b[38;2;249;38;114ma\nreally lon\ng string\x1b[0m",
    "the quick brown\nfoxxxxxxxxxxxxxx\nxx jumped over\nthe lazy dog.",
    "猴 猴 猴猴\n猴猴猴猴猴猴猴猴\n猴 猴猴猴 猴猴\n猴’ 猴猴 猴.",
    "Rotated keys for a-good-offensive-cheat-code-incorporated/animal-like-law-\non-the-rocks.",
    "Rotated keys for a-good-offensive-cheat-code-incorporated/crypto-line-\noperating-system.",
    "a-good-\noffensive-\ncheat-code",
    "foo",
    "\x1b[mfoo\x1b[m",
    "Lorem ipsum dolor \x1b[1msit\x1b[m amet,\nconsectetur adipiscing elit,\nsed do eiusmod tempor\nincididunt ut labore et dolore\n" \
    "magna aliqua. \x1b[31mUt enim\x1b[m ad minim\nveniam, quis nostrud\nexercitation ullamco laboris\nnisi ut aliquip ex ea " \
    "\x1b[38;5;200mcommodo\nconsequat\x1b[m. Duis aute irure\ndolor in reprehenderit in\nvoluptate velit esse cillum\n" \
    "dolore eu fugiat nulla\npariatur. \x1b[1;2;33mExcepteur sint\noccaecat cupidatat non\nproident, sunt in culpa qui\n" \
    "officia deserunt mollit anim\nid est laborum.\x1b[m",
    "foo-\nbar",
    "f  bar\nfoobaz",
    "foobar\n ",
    "foo",
    "foob\narfo\no",
    "foo\nbar\nfoo",
    "foo\nbars\nfoob\nars",
    "foob\n-foo\nbar",
    "foo\n🫧\nfoob\nar",
    "foo --bar",
    "foo\nbar",
    "foo\nb\nar",
    "foo\nb\t a\n bar",
    "foo\nbar\nfoo\n",
    "\nfoo\nbar\n\n\nfoo\n",
    " This\nis a\nlist: \n\n\t* foo\n\t* bar\n\n\n\t* foo\nbar",
    "\x1B[38;2;249;38;114mfoo\x1B[0m\x1B[38;2;248;248;242m \x1B[0m\x1B[38;2;230;219;116mbar\x1B[0m",
    "\x1b[38;2;249;38;114m(\x1b[0m\x1b[38;2;248;248;242mjust\nanother\ntest\x1b[38;2;249;38;114m)\x1b[0m",
    "สวัสดีสวัสดี\x1b]8;;https://example.com\x1b\\\nสวัสดีสวัสดี\x1b]8;;\x1b\\",
    "foo\nbar"
  ].freeze

  # --- upstream: x/cellbuf wrap_test.go expectations, by WRAP_INPUTS index -------------------------
  # (cellbuf's "simple" case uses a different input; it is CELLBUF_SIMPLE below.)
  CELLBUF_WRAP_EXPECTED = [
    nil,
    "hello world",
    "こんに\nち",
    "😃\n👰\u{1f3fb}‍♀️\n🫧",
    "\x1B[38;2;249;38;114ma really\x1b[m\n\x1B[38;2;249;38;114mlong\x1b[m\n\x1B[38;2;249;38;114mstring\x1B[0m",
    "\x1b[38;2;249;38;114ma\x1b[m\n\x1b[38;2;249;38;114mreally lon\x1b[m\n\x1b[38;2;249;38;114mg string\x1b[0m",
    "the quick brown\nfoxxxxxxxxxxxxxx\nxx jumped over\nthe lazy dog.",
    "猴 猴 猴猴\n猴猴猴猴猴猴猴猴\n猴 猴猴猴 猴猴\n猴’ 猴猴 猴.",
    "Rotated keys for a-good-offensive-cheat-code-incorporated/animal-like-law-\non-the-rocks.",
    "Rotated keys for a-good-offensive-cheat-code-incorporated/crypto-line-\noperating-system.",
    "a-good-\noffensive-\ncheat-code",
    "foo",
    "\x1b[mfoo\x1b[m",
    "Lorem ipsum dolor \x1b[1msit\x1b[m amet,\nconsectetur adipiscing elit,\nsed do eiusmod tempor\nincididunt ut labore et dolore\n" \
    "magna aliqua. \x1b[31mUt enim\x1b[m ad minim\nveniam, quis nostrud\nexercitation ullamco laboris\nnisi ut aliquip ex ea " \
    "\x1b[38;5;200mcommodo\x1b[m\n\x1b[38;5;200mconsequat\x1b[m. Duis aute irure\ndolor in reprehenderit in\n" \
    "voluptate velit esse cillum\ndolore eu fugiat nulla\npariatur. \x1b[1;2;33mExcepteur sint\x1b[m\n" \
    "\x1b[1;2;33moccaecat cupidatat non\x1b[m\n\x1b[1;2;33mproident, sunt in culpa qui\x1b[m\n" \
    "\x1b[1;2;33mofficia deserunt mollit anim\x1b[m\n\x1b[1;2;33mid est laborum.\x1b[m",
    "foo-\nbar",
    "f  bar\nfoobaz",
    "foobar\n ",
    "foo",
    "foob\narfo\no",
    "foo\nbar\nfoo",
    "foo\nbars\nfoob\nars",
    "foob\n-foo\nbar",
    "foo\n🫧\nfoob\nar",
    "foo --bar",
    "foo\nbar",
    "foo\nb\nar",
    "foo\nb\t a\n bar",
    "foo\nbar\nfoo\n",
    "\nfoo\nbar\n\n\nfoo\n",
    " This\nis a\nlist: \n\n\t* foo\n\t* bar\n\n\n\t* foo\nbar",
    "\x1B[38;2;249;38;114mfoo\x1B[0m\x1B[38;2;248;248;242m \x1B[0m\x1B[38;2;230;219;116mbar\x1B[0m",
    "\x1b[38;2;249;38;114m(\x1b[0m\x1b[38;2;248;248;242mjust\x1b[m\n\x1b[38;2;248;248;242manother\x1b[m\n" \
    "\x1b[38;2;248;248;242mtest\x1b[38;2;249;38;114m)\x1b[0m",
    "สวัสดีสวัสดี\x1b]8;;https://example.com\x1b\\\x1b]8;;\x07\n\x1b]8;;https://example.com\x07สวัสดีสวัสดี\x1b]8;;\x1b\\",
    "foo\nbar"
  ].freeze

  CELLBUF_SIMPLE = [
    "I really \x1B[38;2;249;38;114mlove the\x1B[0m Go language!", 14,
    "I really \x1B[38;2;249;38;114mlove\x1b[m\n\x1B[38;2;249;38;114mthe\x1B[0m Go\nlanguage!"
  ].freeze

  # --- recorded from the real gem: Lipgloss.width(input) -------------------------------------------
  GEM_WIDTH_CASES = [
    ["", 0],
    ["hello", 5],
    ["hello world", 11],
    ["a\tb", 2],
    ["こんにちは", 10],
    ["打豆豆 abc", 10],
    ["한국어", 6],
    ["ﾊﾝｶｸ", 4],
    ["Ａｂｃ", 6],
    ["👋", 2],
    ["🫧", 2],
    ["😃👰\u{1f3fb}\u{200d}♀\u{fe0f}🫧", 6],
    ["👨\u{200d}👩\u{200d}👦", 2],
    ["\u{1f1f8}\u{1f1e6}", 2],
    ["\u{1f1fa}\u{1f1f8}\u{1f1eb}\u{1f1f7}x", 5],
    ["❤\u{fe0f}", 2],
    ["❤\u{fe0e}", 1],
    ["☺", 1],
    ["☺\u{fe0f}", 2],
    ["©\u{fe0f}", 2],
    ["1\u{fe0f}\u{20e3}", 1],
    ["a\u{300}", 1],
    ["e\u{301}\u{302}z", 2],
    ["\u{200b}", 0],
    ["x\u{200d}y", 2],
    ["⸺⸻", 7],
    ["ก\u{e49}า", 2],
    ["ह\u{93f}न\u{94d}द\u{940}", 5],
    ["ᄀ\u{1161}\u{11a8}", 2],
    ["\e[31mred\e[0m", 3],
    ["\e[38;2;249;38;114m打豆豆\e[m", 6],
    ["\e]8;;https://example.com\a link \e]8;;\a", 6],
    ["\e]8;id=1;https://x.io\e\\リンク\e]8;;\e\\", 6],
    ["\e[?25lhide", 4],
    ["\eP1$r\e\\dcs", 3],
    ["\x9B31mcsi8\x9Bm", 4]
  ].freeze

  # --- recorded from the real gem: Lipgloss::Style.new.width(w).render(input) ----------------------
  GEM_RENDER_CASES = [
    ["I really \e[38;2;249;38;114mlove the\e[0m Go language!", 14,
     "I really \e[38;2;249;38;114mlove\e[m \n\e[38;2;249;38;114mthe\e[0m Go        \nlanguage!     "],
    ["こんにちは世界 hello", 7,
     "こんに \nちは世 \n界     \nhello  "],
    ["😃👰\u{1f3fb}\u{200d}♀\u{fe0f}🫧 \u{1f1f8}\u{1f1e6}\u{1f1fa}\u{1f1f8} ❤\u{fe0f}ok", 4,
     "😃👰\u{1f3fb}\u{200d}♀\u{fe0f}\n🫧  \n\u{1f1f8}\u{1f1e6}\u{1f1fa}\u{1f1f8}\n❤\u{fe0f}ok"],
    ["a\u{300}b\u{301}c\u{302} d\u{303}e\u{304}", 3,
     "a\u{300}b\u{301}c\u{302}\nd\u{303}e\u{304} "],
    ["\e[1;4;38;5;200mbold underline pink text\e[0m and plain", 9,
     "\e[1;4;38;5;200mbold\e[m     \n\e[1;4;38;5;200munderline\e[m\n\e[1;4;38;5;200mpink text\e[0m\nand plain"],
    ["\e[3;48;2;10;20;30mitalic on rgb\e[23;49m tail", 6,
     "\e[3;48;2;10;20;30mitalic\e[m\n\e[3;48;2;10;20;30mon rgb\e[23;49m\ntail  "],
    ["\e[4:3;58:2::1:2:3mcurly underline color\e[m", 7,
     "\e[4:3;58:2::1:2:3mcurly\e[m  \n\e[4:3;58;2;1;2;3munderli\e[m\n\e[4:3;58;2;1;2;3mne\e[m     \n\e[4:3;58;2;1;2;3mcolor\e[m  "],
    ["see \e]8;;https://example.com\ahttps://example.com/a/long/path\e]8;;\a now", 10,
     "see       \n\e]8;;https://example.com\ahttps://ex\e]8;;\a\n\e]8;;https://example.com\aample.com/\e]8;;\a\n" \
     "\e]8;;https://example.com\aa/long/pat\e]8;;\a\n\e]8;;https://example.com\ah\e]8;;\a now     "],
    ["\e]8;id=1;https://x.io\e\\リンクのテキスト\e]8;;\e\\ end", 6,
     "\e]8;id=1;https://x.io\e\\リンク\e]8;;\a\n\e]8;id=1;https://x.io\aのテキ\e]8;;\a\n\e]8;id=1;https://x.io\aスト\e]8;;\e\\  \nend   "],
    ["foo-bar-baz qux", 5,
     "foo- \nbar- \nbaz  \nqux  "],
    ["word  with   spaces   ", 6,
     "word  \nwith  \nspaces"],
    ["supercalifragilisticexpialidocious", 8,
     "supercal\nifragili\nsticexpi\nalidocio\nus      "],
    ["line one\nline two is longer\n\nlast", 7,
     "line   \none    \nline   \ntwo is \nlonger \n       \nlast   "],
    ["trailing space ", 15,
     "trailing space "],
    ["nbsp\u{a0}joined words here", 8,
     "nbsp\u{a0}joi\nned     \nwords   \nhere    "],
    ["\e[31mred\e[0m \e[32mgreen\e[0m \e[34mblue\e[0m", 5,
     "\e[31mred\e[0m  \n\e[32mgreen\e[0m\n\e[34mblue\e[0m "],
    ["\e[93;104mbright\e[0m \e[7;9mrev strike\e[27;29m", 4,
     "\e[93;104mbrig\e[m\n\e[93;104mht\e[0m  \n\e[7;9mrev\e[m \n\e[7;9mstri\e[m\n\e[7;9mke\e[27;29m  "]
  ].freeze

  # --- recorded: Style.new.width(w).tab_width(NO_TAB_CONVERSION).render(input) ---------------------
  GEM_TAB_RENDER_CASES = [
    ["a\tb\tc d", 3,
     "a\tb \nc d"],
    ["\tindent me please", 6,
     "      \nindent\nme    \nplease"]
  ].freeze

  # --- recorded: Style.new.max_width(w).render(input) (single lines, so only ansi.Truncate applies) -
  GEM_MAX_WIDTH_CASES = [
    ["hello world", 5, "hello"],
    ["こんにちは", 5, "こん"],
    ["😃👰\u{1f3fb}\u{200d}♀\u{fe0f}🫧x", 3, "😃"],
    ["\e[31mred text\e[0m after", 6, "\e[31mred te\e[0m"],
    ["\e]8;;https://example.com\alinked text\e]8;;\a", 4, "\e]8;;https://example.com\alink\e]8;;\a"],
    ["a\u{300}b\u{301}c\u{302}", 2, "a\u{300}b\u{301}"],
    ["\u{1f1f8}\u{1f1e6}\u{1f1fa}\u{1f1f8}", 3, "\u{1f1f8}\u{1f1e6}"]
  ].freeze

  # What lipgloss's Style#Render does around cellbuf.Wrap when only a width is set: convert tabs
  # (unless disabled), normalize CRLF, wrap, then pad every line to the block width.
  def render_like_lipgloss(str, width, convert_tabs: true)
    str = str.gsub("\t", "    ") if convert_tabs
    str = str.gsub("\r\n", "\n")
    lines = T.cellbuf_wrap(str, width, "").split("\n", -1)
    lines = [""] if lines.empty?
    widest = lines.map { |l| T.string_width(l) }.max
    lines.map do |l|
      w = T.string_width(l)
      short = (widest - w) + [0, width - widest].max
      l + (" " * short)
    end.join("\n")
  end

  def test_string_width_upstream
    ANSI_WIDTH_CASES.each do |name, input, _stripped, width, _wc|
      assert_equal width, T.string_width(input), name
    end
  end

  def test_strip_upstream
    ANSI_WIDTH_CASES.each do |name, input, stripped, _w, _wc|
      assert_equal stripped.b, T.strip(input).b, name
    end
  end

  def test_string_width_matches_gem
    GEM_WIDTH_CASES.each do |input, width|
      assert_equal width, T.string_width(input), input.inspect
    end
  end

  def test_string_width_ascii_fast_path_counts_only_printables
    assert_equal 6, T.string_width("ab\tc\x01d\x7fef")
    assert_equal 0, T.string_width("\e[31m")
  end

  def test_truncate_upstream
    TRUNCATE_CASES.each do |name, input, tail, width, right, _left|
      assert_equal right.b, T.truncate(input, width, tail).b, name
    end
  end

  def test_truncate_left_upstream
    TRUNCATE_CASES.each do |name, input, prefix, width, _right, left|
      assert_equal left.b, T.truncate_left(input, width, prefix).b, name
    end
  end

  def test_truncate_matches_gem_max_width
    GEM_MAX_WIDTH_CASES.each do |input, width, expected|
      assert_equal expected, T.truncate(input, width, ""), input.inspect
    end
  end

  def test_cut_upstream
    CUT_CASES.each do |desc, input, left, right, expected|
      assert_equal expected, T.cut(input, left, right), desc
    end
  end

  def test_hardwrap_upstream
    HARDWRAP_CASES.each do |name, input, limit, expected, preserve|
      assert_equal expected.b, T.hardwrap(input, limit, preserve).b, name
    end
  end

  def test_wordwrap_upstream
    WORDWRAP_CASES.each do |name, input, limit, breakpoints, expected|
      assert_equal expected, T.wordwrap(input, limit, breakpoints), name
    end
  end

  def test_wrap_upstream
    WRAP_INPUTS.each_with_index do |(name, input, width), i|
      assert_equal ANSI_WRAP_EXPECTED[i], T.wrap(input, width, ""), name
    end
    assert_equal "the quick brown\nfoxxxxxxxxxxxxxx\nxx jumped over\nthe lazy dog.",
                 T.wrap("the quick brown foxxxxxxxxxxxxxxxx jumped over the lazy dog.", 16, "")
    assert_equal "\x1b[91mfoo\x1b[0", T.wrap("\x1b[91mfoo\x1b[0", 3, "")
  end

  def test_cellbuf_wrap_upstream
    input, width, expected = CELLBUF_SIMPLE
    assert_equal expected, T.cellbuf_wrap(input, width, "")
    WRAP_INPUTS.each_with_index do |(name, input2, width2), i|
      next if i.zero?

      # cellbuf's "exact" case closes its SGR (x/ansi's leaves it open); both inputs are covered.
      assert_equal CELLBUF_WRAP_EXPECTED[i], T.cellbuf_wrap(input2, width2, ""), name
    end
    assert_equal "\x1b[91mfoo\x1b[0m", T.cellbuf_wrap("\x1b[91mfoo\x1b[0m", 3, "")
    assert_equal "", T.cellbuf_wrap("", 10, "")
  end

  def test_render_wrap_matches_gem
    GEM_RENDER_CASES.each do |input, width, expected|
      assert_equal expected, render_like_lipgloss(input, width), input.inspect
    end
  end

  def test_render_wrap_with_tabs_matches_gem
    GEM_TAB_RENDER_CASES.each do |input, width, expected|
      assert_equal expected, render_like_lipgloss(input, width, convert_tabs: false), input.inspect
    end
  end

  def test_first_grapheme_cluster
    assert_equal ["👨‍👩‍👦", 2], T.first_grapheme_cluster("👨‍👩‍👦x")
    assert_equal ["\u{1f1f8}\u{1f1e6}", 2], T.first_grapheme_cluster("\u{1f1f8}\u{1f1e6}\u{1f1fa}\u{1f1f8}")
    assert_equal ["é̂", 1], T.first_grapheme_cluster("é̂z")
    assert_equal ["\r\n", 0], T.first_grapheme_cluster("\r\nx")
    assert_equal ["각", 2], T.first_grapheme_cluster("각a")
    assert_equal ["❤︎", 1], T.first_grapheme_cluster("❤︎!")
    assert_equal ["", 0], T.first_grapheme_cluster("")
  end

  # uniseg.StringWidth (chaining the state through FirstGraphemeClusterInString) agrees with the
  # gem's width for text without escape sequences.
  def test_first_grapheme_cluster_in_string_chained_state
    GEM_WIDTH_CASES.each do |input, width|
      next if input.include?("\e") || !input.valid_encoding?

      rest = input
      state = -1
      total = 0
      until rest.empty?
        _cluster, rest, w, state = T.first_grapheme_cluster_in_string(rest, state)
        total += w
      end
      assert_equal width, total, input.inspect
    end
  end
end
