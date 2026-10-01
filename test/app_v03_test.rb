# frozen_string_literal: true

require "test_helper"

# v0.3 app surface: selected_rows for any panel, view at a size, styles, actions on a Context,
# key_pairs, fixed panel widths, sparklines from app series, rows/record while drawing items.
class AppV03Test < Minitest::Test
  Host = Data.define(:id, :name, :load, :trend)

  def setup
    R2UI.reset!
    Fixtures.define_processes
    @extensions = []
  end

  def teardown = @extensions.each { |name| R2UI::Extensions.remove(name) }

  def extension(name, &)
    @extensions << name
    R2UI.extension(name, &)
  end

  def app(name = nil) = R2UI::App.new(R2UI.registry, name).tap { |a| a.snapshot(width: 100, height: 20) }

  def text(app, width = 100, height = 20) = app.frame(width, height).plain_lines.join("\n")

  def actions(&block) = R2UI.resource(:process, extend: true, &block)

  def group_by_directory(app)
    app.press("g", "g")
    text(app)
  end

  # --- selected_rows ---

  def two_tables
    R2UI.dashboard do
      row { panel :procs, resource: :process }
      row { panel :others, resource: :process, title: "Others" }
      row(height: 3) { panel(:note, resource: nil) { view { "sel=#{selected_rows(:others).map(&:name).join(",")}" } } }
    end
    app
  end

  def test_selected_rows_reads_any_table_panel_by_name_or_panel
    app = two_tables
    text(app)
    assert_equal ["cargo"], app.selected_rows.map(&:name)
    assert_equal ["cargo"], app.selected_rows(:others).map(&:name)

    app.press(:tab, "j")
    text(app)
    assert_equal ["claude"], app.selected_rows(:others).map(&:name)
    assert_equal ["claude"], app.selected_rows.map(&:name), "nil is the focused panel"
    assert_equal ["cargo"], app.selected_rows(app.dashboard.panel(:procs)).map(&:name)
    assert_equal [], app.selected_rows(:note), "no table"
    assert_raises(R2UI::Error) { app.selected_rows(:nope) }
  end

  def test_context_selected_rows_takes_a_panel
    app = two_tables
    app.press(:tab, "j")
    text(app)

    assert_match(/sel=claude/, text(app))
  end

  # --- view at a size ---

  def test_view_with_a_size_draws_at_it_and_runs_view_overrides
    extension(:v03_overlay) { view_override { "overlay #{width}x#{height}" if state[:overlay] } }
    R2UI.dashboard { row { panel :process } }
    app = app()

    lines = app.view(width: 40, height: 7).split("\n")
    assert_equal 7, lines.size
    assert_equal 24, app.view.split("\n").size, "no size: the window size"

    app.state[:overlay] = true
    assert_equal "overlay 30x5", app.view(width: 30, height: 5)
    assert_equal "overlay 80x24", app.view

    extension(:v03_short) { frame_size { |w, _h| [w, 4] } }
    assert_equal "overlay 30x4", app.view(width: 30, height: 9), "frame_size hooks still apply"
  end

  # --- styles ---

  def test_styles_merges_every_styles_hook
    R2UI.dashboard { row { panel :process } }
    app = app()
    assert_nil app.styles

    extension(:v03_styles_a) { styles { { accent: "34", ok: "32;1" } } }
    extension(:v03_styles_b) { styles { { accent: "35;1" } } }
    assert_equal({ accent: "35;1", ok: "32;1" }, app.styles)
  end

  # --- actions ---

  def test_action_handler_runs_on_a_context_and_its_flash_stays
    actions do
      action(:kill, key: "K") do |p|
        (state[:killed] ||= []) << p.pid
        flash "bye #{p.name}"
      end
    end
    R2UI.dashboard { row { panel :process } }
    app = app()
    text(app)

    app.press("K")
    assert_equal [12], app.state[:killed]
    assert_match(/bye cargo/, text(app))
    refute_match(/Kill: 1 done/, text(app))
  end

  def test_action_commands_go_out_with_the_update
    cmd = -> { :done }
    actions { action(:kill, key: "K") { |_p| cmd } }
    R2UI.dashboard { row { panel :process } }
    app = app()
    text(app)

    assert_equal [cmd], app.press("K")
    assert_match(/Kill: 1 done/, text(app))
  end

  def test_per_row_action_continues_past_failures
    actions do
      action(:kill, key: "K") do |p|
        raise "#{p.name} is busy" if p.name == "zsh"

        (state[:killed] ||= []) << p.pid
      end
    end
    R2UI.dashboard { row { panel :process } }
    app = app()
    assert_match(/group: Directory/, group_by_directory(app))
    assert_equal 3, app.selected_rows.size

    app.press("K")
    assert_equal [10, 12], app.state[:killed].sort
    assert_match(/Kill: 2 done, 1 failed: zsh is busy/, text(app))
  end

  def test_per_row_action_summaries
    actions do
      action(:kill, key: "K") { |p| (state[:killed] ||= []) << p.pid }
      action(:stop, key: "X") { |p| raise "no #{p.pid}" }
    end
    R2UI.dashboard { row { panel :process } }
    app = app()
    group_by_directory(app)

    app.press("K")
    assert_match(/Kill: 3 done/, text(app))
    app.press("X")
    assert_match(/Stop failed: no \d+/, text(app), "every row failed")
  end

  def test_batch_action_gets_every_row_once
    calls = []
    actions do
      action(:kill, key: "K", batch: true) { |rows| calls << rows.map(&:pid).sort }
      action(:stop, key: "X", batch: true) { |_rows| raise "refused" }
    end
    R2UI.dashboard { row { panel :process } }
    app = app()
    group_by_directory(app)

    app.press("K")
    assert_equal [[10, 11, 12]], calls
    assert_match(/Kill: 3 done/, text(app))
    app.press("X")
    assert_match(/Stop failed: refused/, text(app))
  end

  # --- key_pairs ---

  def test_key_pairs_lists_hints_actions_navigation_then_core
    extension(:v03_hints) { hints { [%w[r refresh]] } }
    actions { action(:kill, key: "K") { |_p| nil } }
    R2UI.dashboard do
      row { panel :process }
      row(height: 3) { panel(:note, resource: nil) { view { "n" } } }
    end
    app = app()
    ext = app.hint_pairs[0...-R2UI::Renderer::HINT_PAIRS.size]
    assert_includes ext, %w[r refresh]

    expected = ext + [%w[K Kill], ["↑/↓ j/k", "move"], %w[pgup/pgdn page], ["home/end", "first/last"]] +
               R2UI::Renderer::HINT_PAIRS
    assert_equal expected, app.key_pairs
    refute_includes app.hint_pairs, %w[K Kill], "the status bar is unchanged"

    app.press(:tab)
    refute_includes app.key_pairs, %w[K Kill], "actions of the focused table panel only"
  end

  # --- panel widths ---

  def widths(app, width = 100) = app.frame(width, 10).then { app.panel_rects.transform_keys(&:name).transform_values(&:width) }

  def test_fixed_width_panels_get_their_width_and_spans_share_the_rest
    R2UI.dashboard do
      row do
        panel(:a, resource: nil, width: 20) { view { "a" } }
        panel(:b, resource: nil) { view { "b" } }
        panel(:c, resource: nil, span: 2) { view { "c" } }
      end
    end
    app = app()

    assert_equal({ a: 20, b: 26, c: 54 }, widths(app))
    app.press("z")
    assert_equal({ a: 100 }, widths(app), "zoom unchanged")
  end

  def test_fixed_widths_wider_than_the_row_shrink_proportionally
    R2UI.dashboard do
      row do
        panel(:a, resource: nil, width: 80) { view { "a" } }
        panel(:b, resource: nil, width: 40) { view { "b" } }
        panel(:c, resource: nil) { view { "c" } }
      end
    end

    assert_equal({ a: 40, b: 20, c: 0 }, widths(app, 60))
  end

  def test_a_fixed_last_panel_takes_the_remainder
    R2UI.dashboard do
      row do
        panel(:a, resource: nil, width: 20) { view { "a" } }
        panel(:b, resource: nil, width: 30) { view { "b" } }
      end
    end

    assert_equal({ a: 20, b: 80 }, widths(app))
  end

  # --- sparklines from app series ---

  def define_hosts(sparkline)
    R2UI.resource :host do
      source do
        [Host.new(id: 1, name: "web", load: 3, trend: [1, 2, 3, 4]),
         Host.new(id: 2, name: "web", load: 4, trend: [4, 4]),
         Host.new(id: 3, name: "db", load: 1, trend: [8, 1])]
      end
      key :id
      group_by :name
      column :name
      column :load, format: :number, sparkline:, sort: :desc
    end
    R2UI.dashboard { row { panel :host } }
  end

  def bars(values) = R2UI::Widgets::Sparkline.line(values, R2UI::Widgets::Table::SPARK_WIDTH).rjust(10)

  def test_table_sparkline_plots_the_rows_series
    define_hosts(:trend)
    app = app()
    assert_includes text(app), "#{bars([8, 1])} "

    app.press("g")
    assert_includes text(app), "#{bars([1, 2, 7, 8])} ", "a group sums its rows' series, newest aligned"
  end

  def test_table_sparkline_from_a_lambda
    define_hosts(->(h) { h.trend.reverse })
    assert_includes text(app), "#{bars([1, 8])} "
  end

  def test_table_sparkline_true_keeps_the_history
    define_hosts(true)
    assert_includes text(app), "#{bars([1.0])} "
  end

  def define_memory(**options)
    R2UI.resource :memory do
      source { { pressure: 36.0, pressure_trend: [10, 50, 100] } }
      attribute :pressure, format: :percent
    end
    R2UI.dashboard do
      row { panel(:memory) { sparkline :pressure, height: 1, **options } }
    end
    app
  end

  def chart_line(app) = app.frame(40, 8).plain_lines[2].delete("│").rstrip

  def test_sparkline_item_plots_the_records_series
    assert_match(/▁▄█\z/, chart_line(define_memory(series: :pressure_trend)))
  end

  def test_sparkline_item_series_from_a_lambda
    assert_match(/█▄▁\z/, chart_line(define_memory(series: ->(m) { m[:pressure_trend].reverse })))
  end

  def test_sparkline_item_without_series_keeps_the_history
    assert_match(/\A\s*▃\z/, chart_line(define_memory))
  end

  # --- rows and record while drawing an item ---

  def test_view_items_see_their_panels_rows_and_record
    R2UI.resource :memory do
      source { { pressure: 36.0 } }
      attribute :pressure, format: :percent
    end
    R2UI.dashboard do
      row { panel(:memory) { view { "p=#{record[:pressure]} n=#{rows.size}" } } }
      row { panel(:none, resource: nil) { view { "rows=#{rows.inspect} record=#{record.inspect}" } } }
    end
    out = text(app)

    assert_match(/p=36.0 n=1/, out)
    assert_match(/rows=\[\] record=nil/, out)
  end
end
