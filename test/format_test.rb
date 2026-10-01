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

  def test_bytes_switches_unit_before_reaching_1000
    assert_equal "0B", F.bytes(0)
    assert_equal "999B", F.bytes(999)
    assert_equal "1.0K", F.bytes(1000)
    assert_equal "1.0K", F.bytes(1023)
    assert_equal "1.5K", F.bytes(1536)
    assert_equal "10K", F.bytes(10_240)
    assert_equal "10K", F.bytes(10_200), "9.96K rounds to 10, so no decimal"
    assert_equal "999K", F.bytes(1_022_976)
    assert_equal "1.0M", F.bytes(1_024_000)
    assert_equal "1.0M", F.bytes(1_048_575)
  end

  def test_bytes_negative_keeps_its_sign
    assert_equal "-2.0K", F.bytes(-2048)
    assert_equal "-999B", F.bytes(-999)
    assert_equal "-2.0K/s", F.call(:bytes_per_sec, -2048)
    assert_equal "1.0K/s", F.call(:bytes_per_sec, 1000)
  end

  def test_bytes_longest_output_fits_the_default_width
    assert_equal 8, F.default_width(:bytes)
    assert_equal 8, F.default_width(:bytes_per_sec)
    assert_equal "-999K/s", F.call(:bytes_per_sec, -1_022_976)
    assert_equal "-999B/s", F.call(:bytes_per_sec, -999)
  end

  def test_si_bytes
    assert_equal "0 B", F.si_bytes(0)
    assert_equal "999 B", F.si_bytes(999)
    assert_equal "1 kB", F.si_bytes(1000)
    assert_equal "12 kB", F.si_bytes(12_345)
    assert_equal "1.5 MB", F.si_bytes(1_500_000)
    assert_equal "1 MB", F.si_bytes(999_999)
    assert_equal "4.2 GB", F.si_bytes(4_200_000_000)
    assert_equal "-1.5 MB", F.si_bytes(-1_500_000)
    assert_equal "12 kB", F.call(:si_bytes, 12_345)
  end

  def test_si_bytes_column_format
    assert F.numeric?(:si_bytes)
    assert_equal :sum, F.default_aggregate(:si_bytes)
    assert_equal :right, F.default_align(:si_bytes)
    assert_equal 8, F.default_width(:si_bytes)
    assert_equal 1_500_000.0, F.parse(:si_bytes, "1.5MB")
    assert_equal 12_000.0, F.parse(:si_bytes, "12 kB")
    assert_equal 500.0, F.parse(:si_bytes, "500")
    assert_nil F.parse(:si_bytes, "lots")
  end

  def test_duration
    assert_equal "120ms", F.duration(0.12)
    assert_equal "3.5s", F.duration(3.456)
    assert_equal "1m 0s", F.duration(59.97)
    assert_equal "1m 15s", F.duration(75.2)
    assert_equal "2h 30m", F.duration(9000)
    assert_equal "1d 2h", F.duration(93_600)
    assert_equal "-1m 15s", F.duration(-75)
    assert_equal "2h 30m", F.call(:duration, 9000)
  end

  def test_duration_column_format
    assert F.numeric?(:duration)
    assert_equal :sum, F.default_aggregate(:duration)
    assert_equal :right, F.default_align(:duration)
    assert_equal 8, F.default_width(:duration)
    assert_equal 45.0, F.parse(:duration, "45")
    assert_equal 90.0, F.parse(:duration, "90s")
    assert_equal 300.0, F.parse(:duration, "5m")
    assert_equal 7200.0, F.parse(:duration, "2h")
    assert_equal 86_400.0, F.parse(:duration, "1d")
    assert_equal 5400.0, F.parse(:duration, "1h30m")
    assert_nil F.parse(:duration, "soon")
  end

  def test_age
    now = Time.at(1_000_000)
    assert_equal "1m 15s", F.age(Time.at(1_000_000 - 75), now:)
    assert_equal "2h 30m", F.age(1_000_000 - 9000, now:), "epoch seconds work too"
    assert_equal "1d 2h", F.call(:age, Time.now - 93_600)
    assert_equal "", F.call(:age, nil)
  end

  def test_age_column_format
    refute F.numeric?(:age)
    assert_equal :min, F.default_aggregate(:age)
    assert_equal :right, F.default_align(:age)
    assert_equal 8, F.default_width(:age)
    assert_equal "5m", F.parse(:age, "5m")
  end

  def test_plural_and_delimit
    assert_equal "1 package", F.plural(1, "package")
    assert_equal "2 dependencies", F.plural(2, "dependency")
    assert_equal "2 children", F.plural(2, "child", "children")
    assert_equal "1,234 files", F.plural(1234, "file")
    assert_equal "1,234,567", F.delimit(1_234_567)
    assert_equal "-1,000.5", F.delimit(-1000.5)
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
