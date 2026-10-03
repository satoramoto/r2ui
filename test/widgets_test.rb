# frozen_string_literal: true

require "test_helper"

# The index table and panel layout options drawn through a real app: column priority, braille
# sparklines, table `columns:` and `motion:`, callable row heights, panel border styles.
class WidgetsTest < Minitest::Test
  Job = Data.define(:id, :name, :cpu)

  def setup
    R2UI.reset!
    @t = 0.0
    @rows = [Job.new(id: 1, name: "alpha", cpu: 30.0), Job.new(id: 2, name: "beta", cpu: 20.0),
             Job.new(id: 3, name: "gamma", cpu: 10.0)]
    rows = -> { @rows }
    R2UI.resource :job do
      source { rows.call }
      key :id
      index do
        column :id, format: :id
        column :name
        column :cpu, format: :percent, sparkline: :braille, sort: :desc
      end
    end
  end

  def app
    @app ||= R2UI::App.new(R2UI.registry).tap { |a| a.motion.clock = -> { @t } }
  end

  def refresh = app.feeds.each_value(&:refresh!)

  def lines(width = 60, height = 10) = app.frame(width, height).plain_lines

  def body(width = 60, height = 10) = lines(width, height)[2..].map { |l| l[1..-2] }.reject { |l| l.strip.empty? }

  def set_cpu(id, cpu) = @rows.map! { |r| r.id == id ? r.with(cpu:) : r }

  # --- column priority ---

  def test_columns_that_do_not_fit_drop_by_priority_then_last_declared
    R2UI.resource :wide do
      source { [{ a: "1", b: "2", c: "3", d: "4" }] }
      index do
        column :a, width: 10, priority: 2
        column :b, width: 10
        column :c, width: 10
        column :d, width: 10, priority: 1
      end
    end
    R2UI.dashboard { row { panel :wide } }
    refresh
    header = ->(w) { lines(w, 6)[1].split(/[│\s]+/).reject(&:empty?) }

    assert_equal %w[A B C D], header.call(45)
    assert_equal %w[A B D], header.call(40), "c: lowest priority, declared after b"
    assert_equal %w[A D], header.call(30)
    assert_equal %w[A], header.call(20)
  end

  # --- braille sparkline cells ---

  def test_braille_spark_cell_shows_baseline_until_it_has_a_shape
    R2UI.dashboard { row { panel :job } }
    refresh
    alpha = body.find { |l| l.include?("alpha") }
    assert_includes alpha, "⠀⠀⠀⠀⢀   30.0%", "one sample is a baseline dot, never a full column"

    set_cpu(1, 60.0)
    refresh
    alpha = body.find { |l| l.include?("alpha") }
    assert_includes alpha, "⠀⠀⠀⠀⣼   60.0%"
  end

  # --- table columns: ---

  def test_table_columns_picks_and_orders_columns
    R2UI.dashboard { row { panel(:job) { table columns: %i[cpu name] } } }
    refresh
    header = lines[1]
    assert_match(/Cpu▼.*Name/, header)
    refute_match(/Id/, header)
    assert_match(/30\.0%.*alpha/, body.first)
  end

  def test_sort_cycles_over_the_selected_columns
    R2UI.dashboard { row { panel(:job) { table columns: %i[cpu name] } } }
    state = app.panel_state(app.dashboard.panels.first)
    assert_equal [:cpu, :desc], state.sort
    app.press("s")
    assert_equal [:name, :asc], state.sort
    app.press("s")
    assert_equal [:cpu, :desc], state.sort, "skips :id, which the table doesn't show"
  end

  def test_unknown_table_column_is_an_error_naming_the_panel
    R2UI.dashboard { row { panel(:jobs, resource: :job) { table columns: %i[name nope] } } }
    error = assert_raises(R2UI::Error) { lines }
    assert_match(/panel jobs/, error.message)
    assert_match(/nope/, error.message)
  end

  # --- motion: gutter marks and selection ---

  def test_motion_marks_moved_and_new_lines_until_they_fade
    R2UI.dashboard { row { panel(:job) { table motion: true } } }
    refresh
    assert(body.none? { |l| l.start_with?("▴", "▾", "•") }, "the first frame marks nothing")

    @t = 0.1
    set_cpu(3, 50.0)
    @rows << Job.new(id: 4, name: "delta", cpu: 5.0)
    refresh
    rows = body
    assert_match(/\A▴.*gamma/, rows[0])
    assert_match(/\A▾.*alpha/, rows[1])
    assert_match(/\A▾.*beta/, rows[2])
    assert_match(/\A•.*delta/, rows[3])
    assert app.motion.active?, "fading marks keep frames coming"

    @t = 1.7
    rows = body
    assert_match(/\A .*gamma/, rows[0], "moves fade after 1.5 s")
    assert_match(/\A•.*delta/, rows[3], "new lines show for 2 s")

    @t = 2.2
    assert(body.none? { |l| l.start_with?("▴", "▾", "•") })
    @t = 4.0
    refute app.motion.active?
  end

  def test_tables_without_motion_have_no_gutter
    R2UI.dashboard { row { panel :job } }
    refresh
    body
    set_cpu(3, 50.0)
    refresh
    assert(body.none? { |l| l.start_with?("▴", "▾", "•") })
  end

  def test_motion_selection_follows_its_line_across_a_resort
    R2UI.dashboard { row { panel(:job) { table motion: true } } }
    refresh
    lines
    app.press(:down)
    lines
    assert_equal [2], app.selected_rows.map(&:id)

    set_cpu(2, 99.0)
    refresh
    lines
    assert_equal [2], app.selected_rows.map(&:id)
    assert_equal 0, app.panel_state(app.dashboard.panels.first).selected
  end

  # --- rows and panels ---

  def test_callable_row_heights_are_evaluated_each_frame_and_clamped
    height = 5
    R2UI.dashboard do
      row(height: -> { height }) { panel :top, resource: :job }
      row { panel :rest, resource: :job }
    end
    top, rest = app.dashboard.panels
    app.frame(60, 20)
    assert_equal [5, 14], [app.panel_rects[top].height, app.panel_rects[rest].height]

    height = 100
    app.frame(60, 20)
    assert_equal [19, 0], [app.panel_rects[top].height, app.panel_rects[rest].height], "clamped to the body"

    height = -4
    app.frame(60, 20)
    assert_equal [0, 19], [app.panel_rects[top].height, app.panel_rects[rest].height]
  end

  def test_border_style_colours_the_border
    colour = "35"
    R2UI.dashboard { row { panel :job, border_style: -> { colour } } }
    assert_match(/\e\[[0-9;]*35m╭/, app.frame(60, 10).ansi_lines.first)
    colour = nil
    refute_match(/35m╭/, app.frame(60, 10).ansi_lines.first, "nil keeps the default border")
  end
end
