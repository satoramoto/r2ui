# frozen_string_literal: true

require "test_helper"

class WidgetsTableWidthsTest < Minitest::Test
  Row = Data.define(:id, :name, :kind)

  def setup
    R2UI.reset!
  end

  def define(rows, kind_label: "Kind")
    R2UI.resource :thing do
      source { rows }
      key :id
      index do
        column :name
        column :kind, label: kind_label
      end
    end
    R2UI.registry.resource(:thing)
  end

  def frame(resource, rows, width)
    lines = R2UI::Query.new(resource, rows).lines
    state = R2UI::PanelState.new(resource)
    canvas = R2UI::Canvas.new(width, lines.size + 1)
    R2UI::Widgets::Table.new(resource, lines, state:, focused: false).draw(canvas, R2UI::Rect.new(x: 0, y: 0, width:, height: lines.size + 1))
    canvas.plain_lines
  end

  def test_long_column_gets_the_room_when_needs_fit
    rows = [Row.new(id: 1, name: "Claude 59 refactoring the table widget", kind: "cli"),
            Row.new(id: 2, name: "Codex 12 writing tests", kind: "app")]
    out = frame(define(rows), rows, 50)
    refute out.join.include?("…"), out.join("\n")
    assert_includes out[1], "Claude 59 refactoring the table widget"
    # Leftover spare is shared, so the table still fills its width: the kind column starts past the name.
    assert_operator out[1].index("cli"), :>, "Claude 59 refactoring the table widget".length
  end

  def test_equal_share_when_nothing_fits
    rows = [Row.new(id: 1, name: "a" * 40, kind: "b" * 40)]
    out = frame(define(rows), rows, 31)
    # 31 = 15 + 1 gap + 15: both columns are truncated to the same width.
    assert_equal "#{"a" * 14}… #{"b" * 14}…", out[1]
  end

  def test_short_column_keeps_its_need_when_the_other_overflows
    rows = [Row.new(id: 1, name: "n" * 60, kind: "ok")]
    out = frame(define(rows, kind_label: "Age"), rows, 30)
    # Age needs 4 (label + sort marker); name gets the other 25.
    assert_equal "#{"n" * 24}… ok", out[1]
    assert_match(/Age/, out[0])
  end

  def test_label_wider_than_values_sets_the_need
    rows = [Row.new(id: 1, name: "x" * 50, kind: "y")]
    out = frame(define(rows, kind_label: "Kind of thing"), rows, 40)
    assert_includes out[0], "Kind of thing"
    assert_equal 40 - 14, out[1].index("y")
  end

  def test_widths_fit_the_rect
    rows = [Row.new(id: 1, name: "a" * 13, kind: "b" * 7)]
    resource = define(rows)
    lines = R2UI::Query.new(resource, rows).lines
    table = R2UI::Widgets::Table.new(resource, lines, state: R2UI::PanelState.new(resource), focused: false)
    [10, 17, 21, 22, 23, 40].each do |w|
      widths = table.send(:widths, w).values
      assert_operator widths.sum + widths.size - 1, :<=, w
      assert(widths.all? { |x| x.is_a?(Integer) && x >= 1 })
    end
    assert_equal 22, table.send(:widths, 22).values.sum + 1
  end
end
