# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

# s28-help: a panel showing Bubbles::Help for the app's key hints.
class HelpTest < Minitest::Test
  def setup
    R2UI.reset!
    R2UI.extension(:help_test_hints) { hints { [%w[r refresh]] } }
  end

  def teardown = R2UI::Extensions.remove(:help_test_hints)

  def define(height: 3)
    R2UI.dashboard do
      row { panel(:main, resource: nil) { view { "main" } } }
      row(height:) { panel(:keys, resource: nil) { help } }
    end
    R2UI::App.new(R2UI.registry)
  end

  # The inner lines of the keys panel (between its box borders).
  def keys_lines(app, width = 200, height = 12)
    lines = app.frame(width, height).plain_lines
    top = lines.index { |l| l.include?("Keys") }
    lines[(top + 1)..].take_while { |l| l.start_with?("│") }.map { |l| l.delete_prefix("│").sub(/│\s*\z/, "").rstrip }
  end

  def test_short_help_shows_core_and_extension_hints_like_bubbles
    app = define

    Bubbles::Help.new.then do |reference|
      bindings = app.hint_pairs.map { |key, label| Bubbles::Key.binding(keys: [key], help: [key, label]) }
      assert_equal [reference.short_help_view(bindings)], keys_lines(app)
    end
    assert_match(/\? help • r refresh • tab panel • \[ \] scope/, keys_lines(app).first)
    assert_match(/q quit\z/, keys_lines(app).first)
  end

  def test_question_mark_toggles_full_help
    app = define(height: 6)

    app.press("?")
    full = keys_lines(app)
    assert_operator full.reject(&:empty?).size, :>, 1, "full help spreads the hints over columns"
    assert_match(/\? help/, full.first)
    assert(full.any? { |l| l.include?("r refresh") })
    assert(full.any? { |l| l.include?("q quit") })
    refute(full.any? { |l| l.include?(" • ") }, "full help has no short separators")

    app.press("?")
    assert_match(/\? help • r refresh/, keys_lines(app).first)
  end

  def test_it_fits_the_panel_width
    app = define
    line = keys_lines(app, 40).first

    assert_operator line.length, :<=, 38
    assert_match(/\A\? help • r refresh • tab panel/, line)
    refute_match(/quit/, line)
    assert(app.frame(40, 12).plain_lines.all? { |l| l.length <= 40 })
  end

  def test_a_one_line_row_shows_short_help
    app = define(height: 1)

    assert_match(/help • r refresh/, app.frame(120, 10).plain_lines.join("\n"))
  end

  def test_full_help_lists_actions_and_navigation_keys
    Fixtures.define_processes
    R2UI.resource(:process, extend: true) { action(:kill, key: "K") { |_p| nil } }
    R2UI.dashboard do
      row { panel :process }
      row(height: 8) { panel(:keys, resource: nil) { help } }
    end
    app = R2UI::App.new(R2UI.registry)

    refute(keys_lines(app, 200, 20).any? { |l| l.include?("K Kill") }, "short help is the status-bar hints")
    app.press("?")
    full = keys_lines(app, 200, 20)
    assert(full.any? { |l| l.include?("K Kill") })
    assert(full.any? { |l| l.include?("↑/↓ j/k move") })
    assert(full.any? { |l| l.include?("q quit") })
  end

  HINT_SETS = [
    [%w[? help], %w[r refresh], %w[tab panel], ["[ ]", "scope"], %w[q quit]],
    [%w[a one]],
    [],
    [["", "no key"], %w[x], ["y", ""], %w[k up], ["↑/↓ j/k", "move"], %w[pgup/pgdn page], %w[z zoom]],
    R2UI::Renderer::HINT_PAIRS + R2UI::App::NAVIGATION_PAIRS
  ].freeze

  def test_builtin_rendering_matches_bubbles_help_byte_for_byte
    HINT_SETS.each do |pairs|
      [0, 1, 7, 20, 40, 200].each do |width|
        [1, 2, 3, 5].each do |height|
          [false, true].each do |full|
            help = Bubbles::Help.new
            help.width = width
            help.show_all = full
            expected = help.view(R2UI::Ext::Help.keymap(pairs, height))
            actual = R2UI::Ext::Help.render(pairs, width:, column_height: height, full:)
            assert_equal expected, actual, "pairs=#{pairs.inspect} width=#{width} height=#{height} full=#{full}"
          end
        end
      end
    end
  end

  def test_it_draws_without_bubbles
    reference = define(height: 6)
    expected_short = keys_lines(reference)
    reference.press("?")
    expected_full = keys_lines(reference)
    R2UI.reset!
    R2UI::Component.stub(:bubbles?, false) do
      app = define(height: 6)
      short = keys_lines(app)
      app.press("?")
      assert_equal [expected_short, expected_full], [short, keys_lines(app)]
      assert_match(/\? help • r refresh/, short.first)
    end
  end

  def test_question_mark_is_left_alone_without_a_help_panel
    R2UI.dashboard { row { panel(:main, resource: nil) { view { "x" } } } }
    app = R2UI::App.new(R2UI.registry)

    app.press("?")
    assert_nil app.store(:help)[:full]
    refute(app.hint_pairs.include?(%w[? help]))
  end
end
