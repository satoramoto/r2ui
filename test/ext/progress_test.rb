# frozen_string_literal: true

require "test_helper"

# s26-progress: a panel item hosting a bubbles Progress bar.
class ProgressTest < Minitest::Test
  def setup = R2UI.reset!

  def plain(app, width = 40, height = 6) = app.frame(width, height).plain_lines.join("\n")

  def bar_line(app, width = 40, height = 6) = app.frame(width, height).plain_lines.find { |l| l.include?("%") }

  def ticks(command)
    case command
    when nil then []
    when Bubbletea::BatchCommand then command.commands.flat_map { |c| ticks(c) }
    else [command]
    end
  end

  def upload_dashboard(**options)
    R2UI.dashboard do
      row do
        panel :status, resource: nil do
          progress(:upload, **options) { state[:sent].to_f / state[:size] }
        end
      end
    end
    R2UI::App.new(R2UI.registry).tap { |app| app.state.merge!(sent: 1, size: 2) }
  end

  def test_hosts_a_bubbles_progress_named_after_the_item
    app = upload_dashboard

    assert_kind_of Bubbles::Progress, app.component(:upload)
  end

  def test_block_fraction_fills_the_panel_width
    app = upload_dashboard
    line = bar_line(app)

    # A 40-wide frame leaves 38 columns inside the box: "  50%" plus a 33-cell bar, half full.
    assert_match(/│#{"█" * 17}#{"░" * 16}  50%│/, line)

    app.state[:sent] = 2
    assert_match(/│#{"█" * 33} 100%│/, bar_line(app), "redrawn from the block every frame")
  end

  def test_width_option_overrides_the_panel_width
    app = upload_dashboard(width: 14)

    assert_match(/│#{"█" * 5}#{"░" * 4}  50% +│/, bar_line(app))
  end

  # Colour output depends on the terminal's profile (none under test), so check the bar was
  # configured the way bubbles' `gradient:` option configures it.
  def test_gradient_option_blends_the_fill
    bar = upload_dashboard(gradient: ["#FF0000", "#0000FF"]).component(:upload)

    assert bar.use_gradient
    assert_equal ["#FF0000", "#0000FF"], [bar.gradient_a, bar.gradient_b]
    assert_raises(ArgumentError) { R2UI.dashboard { row { panel(:p, resource: nil) { progress(:x, gradient: "#fff") { 1 } } } } }
  end

  def test_unusable_fractions_show_empty
    app = upload_dashboard
    app.state.merge!(sent: 0, size: 0)

    assert_match(/│#{"░" * 33}   0%│/, bar_line(app))
  end

  def test_resource_attributes_give_the_fraction
    rows = [{ done: 3, total: 4 }]
    R2UI.resource(:job) { source { rows } }
    R2UI.dashboard do
      row { panel(:job) { progress :done, of: :total } }
    end
    app = R2UI::App.new(R2UI.registry)

    assert_match(/│#{"░" * 33}   0%│/, bar_line(app), "no record fetched yet")

    app.feeds[:job].refresh!
    assert_match(/│#{"█" * 25}#{"░" * 8}  75%│/, bar_line(app))
  ensure
    app&.stop
  end

  def test_animated_progress_springs_towards_the_fraction
    app = upload_dashboard(animate: true)
    _, command = app.init

    assert_match(/   0%│/, bar_line(app), "starts at 0 and animates")
    frame = ticks(command).find { |c| c.is_a?(Bubbletea::TickCommand) }
    refute_nil frame, "init starts the animation"

    shown = []
    300.times do
      break unless frame

      _, out = app.update(frame.callback.call)
      shown << bar_line(app)[/(\d+)%/, 1].to_i
      frame = ticks(out).find { |c| c.is_a?(Bubbletea::TickCommand) }
    end

    assert_nil frame, "the animation settles"
    assert_equal 50, shown.last
    assert(shown.each_cons(2).all? { |a, b| a <= b }, "rises monotonically (critically damped)")
    assert(shown.size > 2, "takes several frames")
  end

  def test_animated_progress_retargets_when_the_fraction_changes
    app = upload_dashboard(animate: true)
    app.init
    assert_in_delta 0.5, app.component(:upload).percent

    app.state[:sent] = 2
    _, out = app.update(Bubbletea::Message.new)

    assert_in_delta 1.0, app.component(:upload).percent
    assert(ticks(out).any?(Bubbletea::TickCommand), "a new animation starts")
  end

  def test_needs_exactly_one_source_of_the_fraction
    assert_raises(ArgumentError) { R2UI.dashboard { row { panel(:p, resource: nil) { progress :x } } } }
    assert_raises(ArgumentError) do
      R2UI.dashboard { row { panel(:p, resource: nil) { progress(:x, of: :y) { 1 } } } }
    end
  end
end
