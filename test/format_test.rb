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
    names = R2UI::Compat::Tea::Input.parse_all("\e[Aq\t\e[Z\x03 \e[6~\x12\ex\e".b)
                                    .map { |event| R2UI::Keys.name(Bubbletea.parse_event(event)) }
    assert_equal [:up, "q", :tab, :back_tab, :interrupt, " ", :page_down, :"ctrl+r", :"alt+x", :escape], names
  end

  def test_keys_round_trip_through_messages
    [:up, :page_up, :back_tab, :enter, :escape, :backspace, :interrupt, "q", " ", :"ctrl+r", :f1].each do |key|
      assert_equal key, R2UI::Keys.name(R2UI::Keys.message(key)), key.inspect
    end
    assert_equal "paste", R2UI::Keys.name(R2UI::Keys.message("paste")), "unknown names are typed text"
    assert_equal "ctrl+r", R2UI::Keys.message("ctrl+r").to_s
  end

  def test_sparkline
    assert_equal "▁▅█", R2UI::Widgets::Sparkline.line([0, 5, 10], 3)
    assert_equal "▁▁", R2UI::Widgets::Sparkline.line([0, 0], 5)
  end
end
