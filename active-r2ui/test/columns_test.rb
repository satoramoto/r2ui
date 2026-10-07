# frozen_string_literal: true

require "test_helper"

module ActiveR2UI
  class ColumnsTest < TestCase
    def specs = Columns.infer(Order).to_h { |s| [s.key, s] }

    def test_formats_by_database_type
      formats = specs.transform_values { |s| s.options[:format] }
      assert_equal :id, formats[:id]
      assert_equal :id, formats[:customer_id]
      assert_equal :number, formats[:total]
      assert_equal :text, formats[:status]
      assert_equal :text, formats[:paid]
      assert_equal :text, formats[:created_at]
    end

    def test_json_columns_are_skipped
      refute specs.key?(:payload)
    end

    def test_readers_convert_values_for_display
      seed_orders
      order = Order.find_by!(status: "shipped")
      read = ->(key) { specs.fetch(key).reader.call(order) }
      assert_equal "99.99", read.call(:total).to_s
      assert_equal "yes", read.call(:paid)
      assert_equal "2h ago", read.call(:created_at).to_s
      assert_equal "leave at door", specs.fetch(:notes).reader.call(Order.find_by!(total: 12.5))
    end

    def test_decimals_keep_their_scale_and_still_sum_sort_and_compare
      a = Decimal.new(BigDecimal("12.5"), 2)
      b = Decimal.new(BigDecimal("99.99"), 2)
      assert_equal "12.50", a.to_s
      assert_equal "112.49", [a, b].sum.to_s # r2ui sums grouped lines from 0
      assert_equal [a, b], [b, a].sort
      assert_operator b, :>, 50.0 # what `total>50` compares against
      assert_equal "0.25", Decimal.new(0.25).to_s
    end

    def test_names_outrank_timestamps_when_columns_must_drop
      priorities = Columns.infer(Customer).to_h { |s| [s.key, s.options[:priority]] }
      assert_operator priorities[:id], :>, priorities[:name]
      assert_operator priorities[:name], :>, priorities[:created_at]
      assert_operator priorities[:created_at], :>, priorities[:updated_at]
    end

    def test_searchable_are_string_and_text_columns
      assert_equal %i[status notes], Columns.searchable(Order)
    end

    def test_timestamp_text_is_relative_and_sorts_by_time
      now = Time.now
      older = Timestamp.new(now - 7200)
      newer = Timestamp.new(now - 90)
      assert_equal "1m ago", newer.to_s(now)
      assert_equal "in 3h", Timestamp.new(now + (3 * 3600) + 5).to_s(now)
      assert_equal (now - (40 * 86_400)).strftime("%Y-%m-%d"), Timestamp.new(now - (40 * 86_400)).to_s(now)
      assert_equal "today", Timestamp.new(now.to_date).to_s(now)
      assert_equal "2d ago", Timestamp.new(now.to_date - 2).to_s(now)
      assert_equal [older, newer], [newer, older].sort
      assert_kind_of Numeric, older # r2ui sorts Numeric values by value, other values by text
    end
  end
end
