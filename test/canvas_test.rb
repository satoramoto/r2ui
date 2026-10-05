# frozen_string_literal: true

require "test_helper"

class CanvasTest < Minitest::Test
  # The Canvas as it was before cells became codepoints: the reference the equivalence tests hold
  # the current one to.
  class ReferenceCanvas
    STYLES = R2UI::Canvas::STYLES
    SGR = /\A\e\[([0-9;:]*)m\z/
    TOKEN = /\e\[[0-9;:]*m|\e(?:\[[0-?]*[ -\/]*[@-~]|\][^\a\e]*(?:\a|\e\\)|[@-_])|[^\e]+|\e/

    attr_reader :width, :height

    def initialize(width, height, styles: nil)
      @width = width
      @height = height
      @palette = styles ? STYLES.merge(styles) : STYLES
      @chars = Array.new(height) { Array.new(width, " ") }
      @styles = Array.new(height) { Array.new(width, :plain) }
    end

    def write_ansi(x, y, text, max: nil)
      return 0 if y.negative? || y >= height

      limit = [max || width, width - x].min
      used = 0
      sgr = nil
      text.to_s.scan(TOKEN).each do |part|
        if (m = part.match(SGR))
          params = m[1]
          sgr = params.empty? || params.match?(/\A0*\z/) ? nil : [sgr, params].compact.join(";")
          next
        end
        next if part.start_with?("\e")

        part.each_char do |ch|
          w = R2UI::Compat::Tea::ANSI.string_width(ch)
          next if w.zero?
          return used if used + w > limit

          put(x + used, y, ch, sgr || :plain)
          put(x + used + 1, y, "", sgr || :plain) if w == 2
          used += w
        end
      end
      used
    end

    def write(x, y, text, style = :plain, max: nil)
      return if y.negative? || y >= height

      limit = [max || width, width - x].min
      text.to_s.each_char.first([limit, 0].max).each_with_index do |ch, i|
        next if (x + i).negative?

        @chars[y][x + i] = ch
        @styles[y][x + i] = style
      end
    end

    def fill(rect, char = " ", style = :plain)
      rect.height.times { |dy| write(rect.x, rect.y + dy, char * rect.width, style) }
    end

    def plain_lines = @chars.map { |row| row.join.rstrip }

    def ansi_lines
      @chars.each_index.map do |y|
        out = +""
        current = nil
        @chars[y].each_with_index do |ch, x|
          style = @styles[y][x]
          out << "\e[0;#{style.is_a?(String) ? style : @palette.fetch(style)}m" if style != current
          current = style
          out << ch
        end
        out << "\e[0m"
      end
    end

    private

    def put(x, y, ch, style)
      return if x.negative? || x >= width

      @chars[y][x] = ch
      @styles[y][x] = style
    end
  end

  def self.chr(cp) = cp.chr(Encoding::UTF_8)

  COMBINING_ACUTE = chr(0x301)
  # ASCII, box drawing, blocks, braille, CJK and other wide chars, emoji (with a skin-tone
  # modifier), and the invisible ones: combining acute, ZWSP, ZWJ, VS16, NBSP, ideographic space.
  TEXT = [
    "a", "Z", " ", "~", "0", "─", "│", "╭", "█", "▁", "⣿", "⠁", "·", "…", "°", "é", "世", "界", "日",
    "🙂", "👍🏽", "\t", "Ω", "ｱ", "한",
    *[0x301, 0x200b, 0x200d, 0xfe0f, 0xa0, 0x3000].map { chr(_1) }
  ].freeze
  ESCAPES = [
    "\e[1m", "\e[0m", "\e[m", "\e[00m", "\e[0;1m", "\e[38;5;205m", "\e[38;2;255;10;0m",
    "\e[48;2;1;2;3m", "\e[4:3m", "\e[2K", "\e[?25l", "\e]2;title\a", "\e]8;;http://x\e\\", "\e7", "\e"
  ].freeze
  STYLE_NAMES = (R2UI::Canvas::STYLES.keys + ["1;31", "38;2;9;9;9"]).freeze

  def random_text(rng, escapes: true)
    Array.new(rng.rand(0..14)) do
      if escapes && rng.rand < 0.3
        ESCAPES.sample(random: rng)
      elsif rng.rand < 0.3
        "plain words "[0, rng.rand(1..12)]
      else
        TEXT.sample(random: rng)
      end
    end.join
  end

  def test_matches_the_reference_canvas_over_generated_writes
    rng = Random.new(20_261_004)
    80.times do |round|
      width = rng.rand(1..24)
      height = rng.rand(1..4)
      ref = ReferenceCanvas.new(width, height)
      canvas = R2UI::Canvas.new(width, height)
      log = []
      40.times do
        x = rng.rand(-6..width + 2)
        y = rng.rand(-1..height)
        max = [nil, nil, rng.rand(-2..width + 3)].sample(random: rng)
        case rng.rand(3)
        when 0
          text = random_text(rng)
          log << [:write_ansi, x, y, text, max]
          assert_equal ref.write_ansi(x, y, text, max:), canvas.write_ansi(x, y, text, max:), log.inspect
        when 1
          text = random_text(rng, escapes: false)
          style = STYLE_NAMES.sample(random: rng)
          log << [:write, x, y, text, style, max]
          ref.write(x, y, text, style, max:)
          canvas.write(x, y, text, style, max:)
        else
          rect = R2UI::Rect.new(x:, y:, width: rng.rand(0..width), height: rng.rand(0..height))
          char = ["·", " ", "█", "x"].sample(random: rng)
          log << [:fill, rect, char]
          ref.fill(rect, char, :muted)
          canvas.fill(rect, char, :muted)
        end
        assert_equal ref.plain_lines, canvas.plain_lines, "round #{round}: #{log.inspect}"
        assert_equal ref.ansi_lines, canvas.ansi_lines, "round #{round}: #{log.inspect}"
      end
    end
  end

  def test_matches_the_reference_for_other_encodings_and_custom_styles
    [
      "binary ok".b, "ascii".encode("US-ASCII"), "caf\xC3\xA9".b, "bad \xFF utf8".dup.force_encoding("UTF-8"),
      "latin \xE9".dup.force_encoding("ISO-8859-1")
    ].each do |text|
      ref = ReferenceCanvas.new(16, 1, styles: { title: "1;35" })
      canvas = R2UI::Canvas.new(16, 1, styles: { title: "1;35" })
      ref.write(1, 0, text, :title)
      canvas.write(1, 0, text, :title)

      %i[plain_lines ansi_lines].each do |lines|
        assert_equal outcome { ref.public_send(lines) }, outcome { canvas.public_send(lines) }, "#{lines} #{text.inspect}"
      end
    end
  end

  # The lines as bytes, or the error class (the old code raised for some encodings; so must we).
  def outcome
    yield.map(&:b)
  rescue StandardError => e
    e.class
  end

  def test_write_ansi_rejects_invalid_utf8_like_before
    text = "ok \xFF".dup.force_encoding("UTF-8")

    assert_raises(ArgumentError) { ReferenceCanvas.new(8, 1).write_ansi(0, 0, text) }
    assert_raises(ArgumentError) { R2UI::Canvas.new(8, 1).write_ansi(0, 0, text) }
  end

  def test_unknown_style_names_still_raise
    canvas = R2UI::Canvas.new(2, 1)
    canvas.write(0, 0, "x", :nope)

    assert_raises(KeyError) { canvas.ansi_lines }
  end

  def test_write_ansi_keeps_colours_per_cell_and_drops_other_escapes
    canvas = R2UI::Canvas.new(10, 1)
    used = canvas.write_ansi(1, 0, "\e[1m\e[38;5;205mhi\e[0m!\e]2;title\a\e[2K")

    assert_equal 3, used
    assert_equal [" hi!"], canvas.plain_lines
    assert_equal "\e[0;0m \e[0;1;38;5;205mhi\e[0;0m!      \e[0m", canvas.ansi_lines.first
  end

  def test_write_ansi_resets_on_every_reset_form
    ["\e[m", "\e[0m", "\e[00m"].each do |reset|
      canvas = R2UI::Canvas.new(3, 1)
      canvas.write_ansi(0, 0, "\e[31ma#{reset}b\e[1;2mc")

      assert_equal "\e[0;31ma\e[0;0mb\e[0;1;2mc\e[0m", canvas.ansi_lines.first, reset.inspect
    end
  end

  def test_write_ansi_clips_and_counts_wide_characters
    canvas = R2UI::Canvas.new(6, 1)

    assert_equal 2, canvas.write_ansi(0, 0, "世界!", max: 3)
    assert_equal ["世"], canvas.plain_lines
    assert_equal 5, canvas.write_ansi(0, 0, "世界!", max: 5)
    assert_equal ["世界!"], canvas.plain_lines
  end

  def test_write_ansi_skips_zero_width_and_cells_off_either_edge
    canvas = R2UI::Canvas.new(4, 1)

    assert_equal 4, canvas.write_ansi(-1, 0, "e#{COMBINING_ACUTE}世ab")
    assert_equal ["世a"], canvas.plain_lines

    canvas = R2UI::Canvas.new(4, 1)

    assert_equal 4, canvas.write_ansi(-2, 0, "世ab")
    assert_equal ["ab"], canvas.plain_lines

    canvas = R2UI::Canvas.new(3, 1)

    assert_equal 1, canvas.write_ansi(1, 0, "a世")
    assert_equal [" a"], canvas.plain_lines
  end

  def test_write_clips_to_max_and_the_right_edge
    canvas = R2UI::Canvas.new(5, 1)
    canvas.write(-2, 0, "abcdefgh")
    canvas.write(3, 0, "XYZ", :bold, max: 1)

    assert_equal ["cdeX"], canvas.plain_lines
    assert_equal "\e[0;0mcde\e[0;1mX\e[0;0m \e[0m", canvas.ansi_lines.first
  end

  def test_styles_override_the_palette
    canvas = R2UI::Canvas.new(2, 1, styles: { title: "1;35" })
    canvas.write(0, 0, "T", :title)

    assert_match(/\e\[0;1;35mT/, canvas.ansi_lines.first)
    assert_match(/\e\[0;1;36mT/, R2UI::Canvas.new(2, 1).tap { _1.write(0, 0, "T", :title) }.ansi_lines.first)
  end
end
