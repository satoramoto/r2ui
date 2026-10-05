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

  def test_string_width_fast_paths_keep_upstream_results
    # One-rune clusters, repeated multi-rune clusters (memoized), and the
    # same bytes in other encodings or invalid.
    cases = [
      "\e[38;2;217;119;87m#{'⣀⣠⣴⣾' * 20}\e[0m ╭──╮ 42.0%",
      "👨‍👩‍👧‍👦👨‍👩‍👧‍👦👨‍👩‍👧‍👦", "❤️❤︎❤", "🇯🇵🇺🇸🇯", "각각",
      "日本語".b, "日本語".dup.force_encoding(Encoding::US_ASCII), "日\xE6本".b,
      "\xF0\x9F\x98a".b, "\e]0;日本\a語".b, "a\xFFbc".b, "─\xC3".b
    ]
    cases.each do |str|
      assert_equal Reference.string_width(str), ANSI.string_width(str), "string_width(#{str.inspect})"
      (0..4).each do |w|
        assert_equal Reference.truncate(str, w).b, ANSI.truncate(str, w).b, "truncate(#{str.inspect}, #{w})"
        assert_equal Reference.truncate(str, w).encoding, ANSI.truncate(str, w).encoding
      end
    end
    assert_equal 100, ANSI.string_width(cases.first + " " * 9)
  end

  def test_string_width_and_truncate_match_reference_on_generated_strings
    rng = Random.new(20_261_004)
    1500.times do
      str = Reference.generate(rng)
      expected = Reference.string_width(str)
      assert_equal expected, ANSI.string_width(str), "string_width(#{str.inspect})"
      [0, 1, 2, 3, expected / 2, expected - 1].uniq.each do |w|
        next if w.negative?

        tail = rng.rand(4).zero? ? "…" : ""
        assert_equal Reference.truncate(str, w, tail).b, ANSI.truncate(str, w, tail).b,
                     "truncate(#{str.inspect}, #{w}, #{tail.inspect})"
      end
    end
  end

  # The implementation as it was before the fast paths (rune-by-rune decode
  # and a \X match per cluster), kept as the reference the fast paths must
  # agree with on every input.
  module Reference
    T = R2UI::Compat::Tea::ANSI
    W = R2UI::Compat::Tea::WidthTable
    PLAIN = /[^\x20-\x7E]/n

    PIECES = [
      "a", "Z", " ", "42.0%", "\t", "\r\n", "\n", "\x00", "\x07", "\x7F",
      "\e[0m", "\e[1;31m", "\e[38;2;217;119;87m", "\e[?25l", "\e[2J", "\e[", "\e[1", "\e[1$",
      "\e]8;;https://x.y\e\\", "\e]0;t\a", "\e]0;日\a", "\e]", "\eP1$r\e\\", "\e_apc é\e\\", "\e^pm\e\\",
      "\eX", "\e(B", "\e", "\x9B31m".b, "\x9D0;x\x9C".b, "\x90q\x9C".b, "\x85".b, "\x98s\x9C".b,
      "─", "│", "╭", "╮", "╰", "╯", "┼", "━", "⣀", "⣠", "⣴", "⣾", "⠁", "▁", "▄", "█", "▴", "▾", "•", "…", "·",
      "日", "本", "ｈ", "ｱ", "é", "é", "́", "̣̈", "क्षि", "؀", "؀a",
      "😀", "👍🏽", "👨‍👩‍👧‍👦", "‍", "❤", "❤️", "❤︎", "☺︎", "️", "︎", "#️⃣", "🏳️‍🌈",
      "\u{1F1E6}", "\u{1F1EF}\u{1F1F5}", "\u{1F1FA}", "각", "ᄀ", "ᅡ", "ᆨ", "ꥠ",
      "​", "­", "⸺", "⸻", "\u{10FFFF}", "�",
      "\xFF".b, "\xC3".b, "\xC3(".b, "\xE2\x94".b, "\xF0\x9F\x98".b, "\xED\xA0\x80".b, "\xF5\x80".b, "\x80".b, "\xC0\xAF".b
    ].freeze

    module_function

    def generate(rng)
      parts = Array.new(rng.rand(0..24)) { PIECES[rng.rand(PIECES.size)] }
      str = parts.map(&:b).join.b
      case rng.rand(4)
      when 0 then str
      when 1 then str.force_encoding(Encoding::US_ASCII)
      else str.force_encoding(Encoding::UTF_8)
      end
    end

    def string_width(str)
      s = str.b
      return 0 if s.empty?
      return s.bytesize unless s.match?(PLAIN)

      pstate = T::GROUND
      width = 0
      i = 0
      n = s.bytesize
      while i < n
        v = T::TABLE[(pstate << 8) | s.getbyte(i)]
        state = v & 15
        if state == T::UTF8
          len, w = first_grapheme_cluster(s, i)
          width += w
          i += len
          pstate = T::GROUND
          next
        end
        width += 1 if (v >> 4) == T::PRINT
        pstate = state
        i += 1
      end
      width
    end

    def truncate(str, length, tail = "")
      return str if string_width(str) <= length

      length -= string_width(tail)
      return +"" if length.negative?

      b = str.b
      buf = +"".b
      tail = tail.b
      cur_width = 0
      ignoring = false
      pstate = T::GROUND
      i = 0
      n = b.bytesize
      while i < n
        byte = b.getbyte(i)
        v = T::TABLE[(pstate << 8) | byte]
        state = v & 15
        if state == T::UTF8
          len, width = first_grapheme_cluster(b, i)
          cluster_start = i
          i += len
          next if ignoring

          if cur_width + width > length
            ignoring = true
            buf << tail
            next
          end

          cur_width += width
          buf << b.byteslice(cluster_start, len)
          pstate = T::GROUND
          next
        end

        if (v >> 4) == T::PRINT
          if cur_width >= length && !ignoring
            ignoring = true
            buf << tail
          end
          if ignoring
            i += 1
            next
          end
          cur_width += 1
        end
        buf << byte
        i += 1

        pstate = state
        if cur_width > length && !ignoring
          ignoring = true
          buf << tail
        end
      end

      buf.force_encoding(str.encoding)
    end

    def first_grapheme_cluster(bytes, i)
      want = 8
      loop do
        runes, lens, done = decode_runes(bytes, i, want)
        cluster = runes.pack("U*")[/\A\X/m]
        count = cluster.length
        return [lens.first(count).sum, cluster_width(runes.first(count))] if count < runes.length || done

        want *= 2
      end
    end

    def decode_runes(bytes, i, max)
      runes = []
      lens = []
      n = bytes.bytesize
      while i < n && runes.length < max
        lead = bytes.getbyte(i)
        size = if lead < 0x80 then 1
               elsif lead >= 0xC2 && lead <= 0xDF then 2
               elsif lead >= 0xE0 && lead <= 0xEF then 3
               elsif lead >= 0xF0 && lead <= 0xF4 then 4
               else 0
               end
        char = size.positive? && bytes.byteslice(i, size).force_encoding(Encoding::UTF_8)
        if char && char.bytesize == size && char.valid_encoding?
          runes << char.ord
          lens << size
          i += size
        else
          runes << 0xFFFD
          lens << 1
          i += 1
        end
      end
      [runes, lens, i >= n]
    end

    def cluster_width(runes)
      first = runes.first
      width = W.width(first)
      if W.extended_pictographic?(first)
        runes.drop(1).each do |r|
          if r == T::VS15 then width = 1
          elsif r == T::VS16 then width = 2
          end
        end
      elsif !W.width_of_first_only?(first)
        runes.drop(1).each { |r| width += W.width(r) }
      end
      width
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

      @available = !env.nil?
    end

    # Where the real gem loads: in this bundle (as the parent finds gems), else outside it.
    def env
      return @env if defined?(@env)

      @env = %i[bundled unbundled].find do |mode|
        ruby_in(mode, %(gem "bubbletea", "0.1.4"; require "bubbletea")).last.success?
      end
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

    def ruby(code, *args) = ruby_in(env || :unbundled, code, *args)

    def ruby_in(mode, code, *args)
      call = -> { Open3.capture2e(RbConfig.ruby, "-e", code, *args) }
      mode == :unbundled && defined?(Bundler) ? Bundler.with_unbundled_env(&call) : call.call
    end
  end
end
