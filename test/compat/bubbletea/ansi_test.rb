# frozen_string_literal: true

require "test_helper"
require "open3"
require "tempfile"
require "rbconfig"
require "r2ui/compat/bubbletea/ansi"

# Expected values were recorded from the real bubbletea 0.1.4 gem
# (charmbracelet/x/ansi v0.8.0). The differential tests re-check them, and a
# wider corpus, against the live gem in a subprocess when it is installed.
class CompatTeaAnsiTest < Minitest::Test
  ANSI = R2UI::Compat::Tea::ANSI

  WIDTHS = {
    "" => 0,
    "hello" => 5,
    "日本語" => 6,
    "ｈｅｌｌｏ" => 10,
    "😀" => 2,
    "👨‍👩‍👧‍👦" => 2,
    "🇯🇵" => 2,
    "🇯🇵🇺🇸" => 4,
    "❤️" => 2,
    "❤" => 1,
    "☺︎" => 1,
    "é" => 1,
    "\e[1;31mred\e[0m" => 3,
    "\e]8;;https://example.com\e\\link\e]8;;\e\\" => 4,
    "\e]8;;https://x.y\alink\e]8;;\a" => 4,
    "tab\there" => 7,
    "a​b" => 2,
    "👍🏽" => 2,
    "각" => 2,
    "क्षि" => 3,
    "⸻" => 4,
    "؀a" => 2,
    "abc\xFFdef".b => 6,
    "\e[38;5;196m日本\e[0m語" => 6,
    "\eP1$r\e\\x" => 1,
    "\e_apc é\e\\z" => 2,
    "각" => 3
  }.freeze

  # [input, width, Truncate(input, width, "")]
  TRUNCATIONS = [
    ["hello world", 5, "hello"],
    ["日本語テキスト", 5, "日本"],
    ["日本語", 1, ""],
    ["\e[1mbold text\e[0m", 4, "\e[1mbold\e[0m"],
    ["👨‍👩‍👧‍👦 family", 3, "👨‍👩‍👧‍👦 "],
    ["🇯🇵🇺🇸", 3, "🇯🇵"],
    ["café au lait", 4, "café"],
    ["\e]8;;https://example.com\e\\link text\e]8;;\e\\", 4, "\e]8;;https://example.com\e\\link\e]8;;\e\\"],
    ["a😀b", 2, "a"],
    ["\e[31m日本\e[0m語", 3, "\e[31m日\e[0m"]
  ].freeze

  CORPUS = (WIDTHS.keys + TRUNCATIONS.map(&:first) + [
    "plain ascii text that is fairly long for truncation",
    "中文字符和English混合",
    "한국어 텍스트",
    "🏳️‍🌈 flag",
    "🏴‍☠️",
    "👩🏽‍💻 coder",
    "#️⃣ keycap",
    "©️ ®",
    "Z̤͔ͧ̑̓ä͖̭̈̇lͮ̒ͫǧ̗͚̚o̙̔ͮ̇͐̇",
    "\e[1m\e[38;2;255;0;0mbold red\e[0m and \e[4munderline\e[24m",
    "\e]8;;https://example.com/日本\e\\日本語リンク\e]8;;\e\\ tail",
    "\e]0;title\a visible",
    "ẍy⃝z",
    "ｱｲｳｴｵ halfwidth",
    "\u{1F1E6}",
    "\u{1F1E6}\u{1F1E8}\u{1F1E9}",
    "\u{2764}\u{FE0F}\u{200D}\u{1F525}",
    "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}",
    "\u{2E3A}wide dash",
    "a\r\nb",
    "\x9B31mX".b,
    "\xC3(bad".b,
    "\e[?25l\e[2J\e[Hscreen",
    " nbsp­"
  ]).uniq.freeze

  def test_string_width_matches_recorded_upstream
    WIDTHS.each do |str, width|
      assert_equal width, ANSI.string_width(str), "string_width(#{str.inspect})"
    end
  end

  def test_truncate_matches_recorded_upstream
    TRUNCATIONS.each do |str, width, expected|
      assert_equal expected.b, ANSI.truncate(str, width).b, "truncate(#{str.inspect}, #{width})"
    end
  end

  def test_truncate_keeps_short_strings_unchanged
    assert_equal "hello", ANSI.truncate("hello", 5)
    assert_equal "", ANSI.truncate("", 3)
  end

  def test_string_width_differential_against_real_gem
    skip "bubbletea 0.1.4 not installed" unless RealTea.available?

    expected = RealTea.run(CORPUS.map { |s| [:width, s] })
    CORPUS.zip(expected).each do |str, width|
      assert_equal width, ANSI.string_width(str), "string_width(#{str.inspect})"
    end
  end

  def test_truncate_differential_against_real_gem
    skip "bubbletea 0.1.4 not installed" unless RealTea.available?

    # The renderer splits on "\n", so only single-line strings measure Truncate.
    cases = CORPUS.reject { |s| s.empty? || s.include?("\n") }.flat_map { |s| [1, 2, 3, 5, 8, 13].map { |w| [s, w] } }
    frames = RealTea.run(cases.map { |s, w| [:frames, [[:size, w, 0], [:render, s]]] })
    cases.zip(frames).each do |(str, width), (_, out)|
      # A one-line inline frame is "\r" + line + EraseLine(0) + "\r".
      expected = out.byteslice(1, out.bytesize - 5)
      assert_equal expected, ANSI.truncate(str, width).b, "truncate(#{str.inspect}, #{width})"
    end
  end

  # Runs jobs against the real gem in a separate Ruby process (its native
  # extension must never load into this one).
  module RealTea
    SCRIPT = <<~'RUBY'
      require "bubbletea"
      jobs = Marshal.load(File.binread(ARGV[0]))
      cap = ARGV[2]
      STDOUT.reopen(cap, "wb")
      program = Bubbletea::Program.new
      out = jobs.map do |kind, arg|
        case kind
        when :width then program.string_width(arg)
        when :frames
          id = program.create_renderer
          arg.map do |op, *a|
            before = File.size(cap)
            case op
            when :size then program.renderer_set_size(id, *a)
            when :alt then program.renderer_set_alt_screen(id, a[0])
            when :render then program.render(id, a[0])
            when :clear then program.renderer_clear(id)
            end
            File.binread(cap).byteslice(before..)
          end
        end
      end
      File.binwrite(ARGV[1], Marshal.dump(out))
    RUBY

    module_function

    def available?
      return @available if defined?(@available)

      @available = !Gem::Specification.find_all_by_name("bubbletea", "0.1.4").empty? ||
                   ruby(%(gem "bubbletea", "0.1.4"; require "bubbletea")).last.success?
    end

    def run(jobs)
      Tempfile.create("tea-jobs") do |input|
        Tempfile.create("tea-out") do |output|
          Tempfile.create("tea-stdout") do |captured|
            input.binmode.write(Marshal.dump(jobs))
            input.close
            log, status = ruby(SCRIPT, input.path, output.path, captured.path)
            raise "real bubbletea failed: #{log}" unless status.success?

            Marshal.load(File.binread(output.path))
          end
        end
      end
    end

    def ruby(code, *args)
      call = -> { Open3.capture2e(RbConfig.ruby, "-e", code, *args) }
      defined?(Bundler) ? Bundler.with_unbundled_env(&call) : call.call
    end
  end
end
