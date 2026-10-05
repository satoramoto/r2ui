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
end
