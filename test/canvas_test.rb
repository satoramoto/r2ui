# frozen_string_literal: true

require "test_helper"

class CanvasTest < Minitest::Test
  def test_write_ansi_keeps_colours_per_cell_and_drops_other_escapes
    canvas = R2UI::Canvas.new(10, 1)
    used = canvas.write_ansi(1, 0, "\e[1m\e[38;5;205mhi\e[0m!\e]2;title\a\e[2K")

    assert_equal 3, used
    assert_equal [" hi!"], canvas.plain_lines
    assert_equal "\e[0;0m \e[0;1;38;5;205mhi\e[0;0m!      \e[0m", canvas.ansi_lines.first
  end

  def test_write_ansi_clips_and_counts_wide_characters
    canvas = R2UI::Canvas.new(6, 1)

    assert_equal 2, canvas.write_ansi(0, 0, "世界!", max: 3)
    assert_equal ["世"], canvas.plain_lines
    assert_equal 5, canvas.write_ansi(0, 0, "世界!", max: 5)
    assert_equal ["世界!"], canvas.plain_lines
  end

  def test_styles_override_the_palette
    canvas = R2UI::Canvas.new(2, 1, styles: { title: "1;35" })
    canvas.write(0, 0, "T", :title)

    assert_match(/\e\[0;1;35mT/, canvas.ansi_lines.first)
  end
end
