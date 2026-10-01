# frozen_string_literal: true

require "test_helper"

# s02-view, the reference panel item.
class ViewTest < Minitest::Test
  def setup = R2UI.reset!

  def text(app, width = 40, height = 8) = app.frame(width, height).plain_lines.join("\n")

  def test_view_draws_its_lines_with_the_space_it_has
    R2UI.dashboard do
      row do
        panel :hello, resource: nil do
          view { "hello #{state[:name]}\n#{width}x#{height}" }
          view { "\e[35mstyled\e[0m" }
        end
      end
    end
    app = R2UI::App.new(R2UI.registry)
    app.state[:name] = "ryan"

    assert_match(/╭─ Hello ─/, text(app))
    assert_match(/│hello ryan/, text(app))
    assert_match(/│38x5/, text(app), "inner size of a 40x8 frame: box borders and the status bar")
    assert_match(/│styled/, text(app))
    assert(app.frame(40, 8).ansi_lines.any? { |l| l.include?("\e[0;35ms") })
  end

  def test_view_lines_are_clipped_to_the_panel
    R2UI.dashboard do
      row { panel(:long, resource: nil) { view { (1..20).map { |i| "line #{i} #{"x" * 60}" }.join("\n") } } }
    end
    out = text(R2UI::App.new(R2UI.registry), 30, 6)

    assert_match(/line 3/, out)
    refute_match(/line 4/, out)
    assert(out.lines.all? { |l| l.chomp.length <= 30 })
  end

  def test_view_sits_under_core_items
    Fixtures.define_processes
    R2UI.dashboard do
      row do
        panel :process do
          view { "#{selected_rows.size} selected" }
          table limit: 2
        end
      end
    end

    assert_match(/│0 selected/, text(R2UI::App.new(R2UI.registry), 80, 10))
  end
end
