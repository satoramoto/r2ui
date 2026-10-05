# frozen_string_literal: true

require "test_helper"

class GlyphsTest < Minitest::Test
  G = R2UI::Widgets::Glyphs

  def test_braille_line_flat_zero_is_baseline_dots
    assert_equal "⣀⣀⣀", G.braille_line([0, 0, 0, 0, 0, 0], 3)
    assert_equal "⠀⠀", G.braille_line([0, 0, 0, 0], 2, baseline: false)
  end

  def test_braille_line_scales_two_samples_per_cell_newest_right
    assert_equal "⣸", G.braille_line([0, 4], 1, max: 4), "left baseline, right full"
    assert_equal "⣠⣾", G.braille_line([0, 2, 3, 4], 2, max: 4)
    assert_equal "⣸", G.braille_line([9, 9, 9, 0, 4], 1, max: 4), "keeps only the last width * 2"
    assert_equal "", G.braille_line([1, 2], 0)
  end

  def test_braille_line_pads_short_history_on_the_left
    assert_equal "⠀⢀", G.braille_line([0], 2)
    assert_equal "⠀⢸", G.braille_line([5], 2), "one sample alone scales to the top"
  end

  def test_braille_area_has_height_rows_filled_from_the_bottom
    rows = G.braille_area([8, 2], 1, 2, max: 8)
    assert_equal 2, rows.size
    assert_equal ["⡇", "⣧"], rows, "left 8 of 8 levels, right 2"
    assert_equal %w[⠀⠀⠀ ⠀⠀⠀ ⠀⠀⠀], G.braille_area([0, 0], 3, 3)
    assert_equal [], G.braille_area([1], 2, 0)
    assert_equal ["", ""], G.braille_area([1], 0, 2)
  end

  def test_bar_uses_eighths
    assert_equal "██  ", G.bar(0.5, 4)
    assert_equal "▋ ", G.bar(0.3, 2)
    assert_equal "▏", G.bar(1 / 16.0, 1)
    assert_equal "███", G.bar(1.0, 3)
    assert_equal "██", G.bar(7, 2), "clamped"
    assert_equal "  ", G.bar(-1, 2)
    assert_equal "", G.bar(0.5, 0)
  end

  def test_heat_endpoints_and_middle
    assert_equal "38;2;95;175;95", G.heat(0)
    assert_equal "38;2;229;165;10", G.heat(0.5)
    assert_equal "38;2;229;72;77", G.heat(1)
    assert_equal "38;2;229;72;77", G.heat(3), "clamped"
    assert_equal "38;2;0;0;0", G.heat(0.7, stops: ["#000000"])
  end

  def test_colour_helpers
    assert_equal "38;2;1;2;3", G.fg("#010203")
    assert_equal "48;2;255;255;255", G.bg("#fff")
    assert_equal "\e[1mx\e[0m", G.paint("x", "1")
    assert_equal "x", G.paint("x", nil)
  end

  # The colour of `fraction` worked out from scratch: 65 steps, a plain RGB lerp between stops.
  def reference_heat(fraction, stops)
    t = (fraction.to_f.clamp(0.0, 1.0) * 64).round / 64.0
    rgb = ->(hex) { hex.delete_prefix("#").scan(/../).map { |p| p.to_i(16) } }
    return "38;2;#{rgb.call(stops.first).join(";")}" if stops.size == 1

    pos = t * (stops.size - 1)
    i = [pos.floor, stops.size - 2].min
    mixed = rgb.call(stops[i]).zip(rgb.call(stops[i + 1])).map { |a, b| (a + ((b - a) * (pos - i))).round.clamp(0, 255) }
    "38;2;#{mixed.join(";")}"
  end

  def test_heat_sweep_matches_the_gradient_for_default_and_custom_stops
    custom = ["#000000", "#102030", "#FFFFFF", "#7F00FF"]
    (-10..210).each do |n|
      fraction = n / 200.0
      assert_equal reference_heat(fraction, G::HEAT), G.heat(fraction), "default stops at #{fraction}"
      assert_equal reference_heat(fraction, custom), G.heat(fraction, stops: custom.dup), "custom stops at #{fraction}"
      assert_equal reference_heat(fraction, ["#5FAF5F", "#E5A50A", "#E5484D"]),
                   G.heat(fraction, stops: ["#5FAF5F", "#E5A50A", "#E5484D"]), "an equal copy of HEAT"
    end
  end

  def test_heat_follows_stops_changed_after_a_call
    stops = ["#000000", "#FFFFFF"]
    assert_equal "38;2;255;255;255", G.heat(1, stops:)
    stops[1] = "#0000FF"
    assert_equal "38;2;0;0;255", G.heat(1, stops:), "a cached table is keyed by the stops' values"
    assert_equal "38;2;0;0;128", G.heat(0.5, stops:)
  end

  # One braille line built the plain way: window, levels, padded pairs of dots.
  def reference_braille(values, width, max: nil, baseline: true)
    window = values.last(width * 2).map(&:to_f)
    top = max || window.max
    top = top.nil? || top <= 0 ? 1.0 : top.to_f
    levels = window.map { |v| v <= 0 ? (baseline ? 1 : 0) : ((v / top) * 4).round.clamp(1, 4) }
    (Array.new((width * 2) - levels.size) + levels).each_slice(2).map do |l, r|
      bits = (l ? G::LEFT.first(l).sum : 0) | (r ? G::RIGHT.first(r).sum : 0)
      (0x2800 + bits).chr(Encoding::UTF_8)
    end.join
  end

  def test_braille_line_sweep_matches_the_plain_construction
    rng = Random.new(7)
    200.times do
      values = Array.new(rng.rand(0..14)) { [0, -1, rng.rand(100), rng.rand * 50, 3].sample(random: rng) }
      width = rng.rand(1..6)
      max = [nil, nil, 0, 25, 100.0].sample(random: rng)
      baseline = rng.rand < 0.7
      assert_equal reference_braille(values, width, max:, baseline:), G.braille_line(values, width, max:, baseline:),
                   "#{values.inspect} width #{width} max #{max.inspect} baseline #{baseline}"
    end
  end

  def test_fg_and_bg_repeat_the_same_value
    hexes = ["#010203", "#fff", "abcdef", "#D97757"]
    2.times do
      assert_equal ["38;2;1;2;3", "38;2;255;255;255", "38;2;171;205;239", "38;2;217;119;87"], hexes.map { G.fg(_1) }
      assert_equal ["48;2;1;2;3", "48;2;255;255;255", "48;2;171;205;239", "48;2;217;119;87"], hexes.map { G.bg(_1) }
    end
  end
end
