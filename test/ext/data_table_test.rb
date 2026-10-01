# frozen_string_literal: true

require "test_helper"

# s23-data-table: `data_table :name, columns:, rows:, on_select:` hosts a Bubbles::Table in a panel.
class DataTableTest < Minitest::Test
  ROWS = [%w[api 3], %w[web 5], %w[db 1], %w[cache 2]].freeze

  def setup
    R2UI.reset!
    @selected = []
    selected = @selected
    R2UI.dashboard do
      row height: 8 do
        panel :services, resource: nil do
          data_table :services,
                     columns: [["Name", 10], ["Count", 5]],
                     rows: -> { ROWS },
                     on_select: ->(row) { selected << row }
        end
      end
    end
    @app = R2UI::App.new(R2UI.registry)
    @app.init
  end

  def teardown = @app&.stop

  def text(width = 40, height = 10) = @app.frame(width, height).plain_lines.join("\n")

  def test_hosts_a_bubbles_table
    assert_kind_of Bubbles::Table, @app.component(:services)
  end

  def test_draws_headers_and_rows
    out = text

    assert_match(/Name\s+Count/, out)
    assert_match(/api\s+3/, out)
    assert_match(/cache\s+2/, out)
  end

  def test_column_widths_come_from_the_columns
    assert_equal [10, 5], @app.component(:services).columns.map(&:width)
    assert_equal %w[Name Count], @app.component(:services).columns.map(&:title)
  end

  def test_down_arrow_moves_the_cursor_while_focused
    text
    @app.press(:down, :down)

    assert_equal 2, @app.component(:services).cursor
  end

  def test_up_arrow_moves_back
    text
    @app.press(:down, :down, :up)

    assert_equal 1, @app.component(:services).cursor
  end

  def test_enter_calls_on_select_with_the_row
    text
    @app.press(:down, :enter)

    assert_equal [%w[web 5]], @selected
  end

  def test_enter_on_the_first_row
    text
    @app.press(:enter)

    assert_equal [%w[api 3]], @selected
  end

  def test_the_table_is_sized_to_the_panel
    text(40, 10)

    assert_operator @app.component(:services).height, :>, 0
    assert_operator @app.component(:services).height, :<=, 8
  end

  def test_rows_refresh_from_the_lambda
    rows = [%w[one 1]]
    R2UI.reset!
    R2UI.dashboard do
      row height: 8 do
        panel :live, resource: nil do
          data_table :live, columns: [["Name", 10]], rows: -> { rows }
        end
      end
    end
    app = R2UI::App.new(R2UI.registry)
    app.init
    assert_match(/one/, app.frame(40, 10).plain_lines.join("\n"))

    rows.replace([%w[two 2]])

    assert_match(/two/, app.frame(40, 10).plain_lines.join("\n"))
  ensure
    app&.stop
  end

  def test_needs_a_name_and_columns
    assert_raises(ArgumentError) do
      R2UI.dashboard(:bad) { row { panel(:p, resource: nil) { data_table columns: [["A", 3]], rows: -> { [] } } } }
    end
    assert_raises(ArgumentError) do
      R2UI.dashboard(:bad) { row { panel(:p, resource: nil) { data_table :t, rows: -> { [] } } } }
    end
  end
end
