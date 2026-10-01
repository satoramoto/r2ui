# frozen_string_literal: true

require "test_helper"

class FormatTest < Minitest::Test
  F = R2UI::Format

  def test_bytes
    assert_equal "512B", F.call(:bytes, 512)
    assert_equal "1.5K", F.call(:bytes, 1536)
    assert_equal "400M", F.call(:bytes, 400 * 1024**2)
    assert_equal "2.0G", F.call(:bytes, 2 * 1024**3)
    assert_equal "3.0M/s", F.call(:bytes_per_sec, 3 * 1024**2)
  end

  def test_percent_ratio_and_nil
    assert_equal "12.3%", F.call(:percent, 12.34)
    assert_equal "2.5x", F.call(:ratio, 2.46)
    assert_equal "", F.call(:bytes, nil)
  end

  def test_short_path
    assert_equal "~/code", F.call(:short_path, File.join(Dir.home, "code"))
  end

  def test_parse
    assert_equal 500 * 1024**2, F.parse(:bytes, "500M")
    assert_equal 1.5 * 1024**3, F.parse(:bytes, "1.5GB")
    assert_equal 5.0, F.parse(:percent, "5%")
    assert_nil F.parse(:bytes, "lots")
  end

  def test_keys
    assert_equal [:up, "q", :tab, :back_tab, :escape], R2UI::Keys.parse("\e[Aq\t\e[Z\e")
  end

  def test_sparkline
    assert_equal "▁▅█", R2UI::Widgets::Sparkline.line([0, 5, 10], 3)
    assert_equal "▁▁", R2UI::Widgets::Sparkline.line([0, 0], 5)
  end
end
