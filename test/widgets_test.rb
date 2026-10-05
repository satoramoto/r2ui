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

  # --- exact table drawing ---

  # Forwards to the real canvas and logs every write and fill the table makes.
  class RecordingCanvas
    attr_reader :log

    def initialize(canvas)
      @canvas = canvas
      @log = []
    end

    def write(x, y, text, style = :plain, max: nil)
      @log << "w #{x},#{y} #{style.inspect} max=#{max.inspect} |#{text}|"
      @canvas.write(x, y, text, style, max:)
    end

    def fill(rect, char = " ", style = :plain)
      @log << "f #{rect.x},#{rect.y},#{rect.width}x#{rect.height} #{style.inspect} |#{char}|"
      @canvas.fill(rect, char, style)
    end
  end

  # The table's writes and fills for one frame.
  def table_log(width, height)
    log = []
    real_new = R2UI::Widgets::Table.method(:new)
    recorder = lambda do |*args, **kwargs|
      table = real_new.call(*args, **kwargs)
      table.define_singleton_method(:draw) do |canvas, rect|
        recording = RecordingCanvas.new(canvas)
        super(recording, rect)
        log.concat(recording.log)
      end
      table
    end
    R2UI::Widgets::Table.stub(:new, recorder) { app.frame(width, height) }
    log
  end

  # Every string and style a wide table draws: heat-coloured cells from a style lambda, a percent
  # column, braille and bar sparklines with a callable spark style, truncation, motion marks, the
  # selection and a grouped label line.
  def test_wide_table_draws_exact_strings_and_styles
    proc_row = Data.define(:id, :name, :team, :cpu, :mem, :note)
    data = [proc_row.new(id: 1, name: "a-very-long-process-name", team: "core", cpu: 85.0, mem: 10.0, note: "hot"),
            proc_row.new(id: 2, name: "beta", team: "core", cpu: 40.0, mem: 30.0, note: "warm"),
            proc_row.new(id: 3, name: "gamma", team: "web", cpu: 5.0, mem: 90.0, note: "")]
    rows = -> { data }
    heat = ->(v, _line) { R2UI::Widgets::Glyphs.heat(v / 100.0) if v.is_a?(Numeric) }
    spark_heat = ->(values, _line) { R2UI::Widgets::Glyphs.heat((values.last || 0) / 100.0) }
    R2UI.resource :proc do
      source { rows.call }
      key :id
      group_by :team
      index do
        column :id, format: :id
        column :name, width: 12
        column :team
        column :cpu, format: :percent, sparkline: :braille, sort: :desc, style: heat, spark_style: spark_heat
        column :mem, format: :percent, sparkline: true, spark_width: 6
        column :note
      end
    end
    R2UI.dashboard { row { panel(:proc) { table motion: true } } }
    refresh
    lines(100, 8)
    @t = 0.3
    data = [data[0].with(cpu: 20.0), data[1].with(cpu: 60.0), data[2].with(cpu: 95.0, mem: 50.0),
            proc_row.new(id: 4, name: "delta", team: "web", cpu: 33.3, mem: 0.0, note: "new")]
    refresh
    app.press(:down)
    @t = 0.9
    moving = table_log(100, 8)
    @t = 1.6
    faded = table_log(100, 8).grep(/max=nil/)
    app.press("g")
    grouped = table_log(100, 8)

    assert_equal TABLE_LOG, [*moving, "--", *grouped, "--", *faded].join("\n")
  end

  def test_history_sum_of_one_series_and_of_several
    history = R2UI::History.new(capacity: 4)
    [1, 2, 3, 4, 5].each { |v| history.record(:a, :cpu, v) }
    [10, 20, 30, 40].each { |v| history.record(:b, :cpu, v) }
    assert_equal [2.0, 3.0, 4.0, 5.0], history.sum([:a], :cpu)
    assert_equal [12.0, 23.0, 34.0, 45.0], history.sum(%i[a b], :cpu)
    assert_equal [], history.sum([:none], :cpu)
    assert_equal [], history.sum([], :cpu)
    assert_equal [4.0, 6.0, 8.0, 10.0], history.sum(%i[a a], :cpu), "a repeated id counts twice"
  end

  TABLE_LOG = <<~LOG.chomp
    w 2,1 :header max=8 |      Id|
    w 11,1 :header max=12 |Name        |
    w 24,1 :header max=22 |Team                  |
    w 47,1 :header max=13 |         Cpu▼|
    w 61,1 :header max=14 |           Mem|
    w 76,1 :header max=22 |Note                  |
    w 2,2 :plain max=8 |       3|
    w 11,2 :plain max=12 |gamma       |
    w 24,2 :plain max=22 |web                   |
    w 47,2 "38;2;229;81;71" max=13 |⠀⠀⠀⠀⣸|
    w 52,2 :plain max=8 | |
    w 53,2 "38;2;229;81;71" max=7 |  95.0%|
    w 61,2 :plain max=14 |    █▅|
    w 67,2 :plain max=8 | |
    w 68,2 :plain max=7 |  50.0%|
    w 76,2 :plain max=22 |                      |
    w 1,2 "38;2;217;119;87" max=nil |▴|
    f 1,3,98x1 :selected | |
    w 2,3 :selected max=8 |       2|
    w 11,3 :selected max=12 |beta        |
    w 24,3 :selected max=22 |core                  |
    w 47,3 :selected max=13 |⠀⠀⠀⠀⣾|
    w 52,3 :selected max=8 | |
    w 53,3 :selected max=7 |  60.0%|
    w 61,3 :selected max=14 |    ██|
    w 67,3 :selected max=8 | |
    w 68,3 :selected max=7 |  30.0%|
    w 76,3 :selected max=22 |warm                  |
    w 2,4 :plain max=8 |       4|
    w 11,4 :plain max=12 |delta       |
    w 24,4 :plain max=22 |web                   |
    w 47,4 "38;2;183;168;39" max=13 |⠀⠀⠀⠀⢀|
    w 52,4 :plain max=8 | |
    w 53,4 "38;2;183;168;39" max=7 |  33.3%|
    w 61,4 :plain max=14 |     ▁|
    w 67,4 :plain max=8 | |
    w 68,4 :plain max=7 |   0.0%|
    w 76,4 :plain max=22 |new                   |
    w 1,4 "38;2;217;119;87" max=nil |•|
    w 2,5 :plain max=8 |       1|
    w 11,5 :plain max=12 |a-very-long…|
    w 24,5 :plain max=22 |core                  |
    w 47,5 "38;2;149;171;60" max=13 |⠀⠀⠀⠀⣇|
    w 52,5 :plain max=8 | |
    w 53,5 "38;2;149;171;60" max=7 |  20.0%|
    w 61,5 :plain max=14 |    ██|
    w 67,5 :plain max=8 | |
    w 68,5 :plain max=7 |  10.0%|
    w 76,5 :plain max=22 |hot                   |
    w 1,5 "38;2;217;119;87" max=nil |▾|
    --
    w 2,1 :header max=8 |      Id|
    w 11,1 :header max=12 |Name        |
    w 24,1 :header max=22 |Team                  |
    w 47,1 :header max=13 |         Cpu▼|
    w 61,1 :header max=14 |           Mem|
    w 76,1 :header max=22 |Note                  |
    f 1,2,98x1 :selected | |
    w 2,2 :selected max=8 |      ×2|
    w 11,2 :selected max=12 |            |
    w 24,2 :selected max=22 |web|
    w 47,2 :selected max=13 |⠀⠀⠀⠀⣸|
    w 52,2 :selected max=8 | |
    w 53,2 :selected max=7 | 128.3%|
    w 61,2 :selected max=14 |    █▅|
    w 67,2 :selected max=8 | |
    w 68,2 :selected max=7 |  50.0%|
    w 76,2 :selected max=22 |                      |
    w 2,3 :plain max=8 |      ×2|
    w 11,3 :plain max=12 |            |
    w 24,3 :bold max=22 |core|
    w 47,3 "38;2;229;110;50" max=13 |⠀⠀⠀⠀⣷|
    w 52,3 :plain max=8 | |
    w 53,3 "38;2;229;110;50" max=7 |  80.0%|
    w 61,3 :plain max=14 |    ██|
    w 67,3 :plain max=8 | |
    w 68,3 :plain max=7 |  40.0%|
    w 76,3 :plain max=22 |                      |
    --
    w 1,2 "38;2;155;103;86" max=nil |▴|
    w 1,4 "38;2;171;107;86" max=nil |•|
    w 1,5 "38;2;155;103;86" max=nil |▾|
  LOG
end
