# frozen_string_literal: true

require "test_helper"

# s20-text-input: a panel hosting a Bubbles::TextInput.
class TextInputTest < Minitest::Test
  def setup
    R2UI.reset!
    Fixtures.define_processes
    R2UI.dashboard do
      on_submit = ->(value) { state[:submitted] = value }
      row do
        panel :search, resource: nil do
          text_input :query, placeholder: "filter…", prompt: "? ", width: 20, char_limit: 5, on_submit: on_submit
        end
      end
      row { panel :process }
    end
    @app = R2UI::App.new(R2UI.registry)
    @app.focus = @app.dashboard.panels.first
  end

  def teardown = @app.stop

  def text(width = 40, height = 12) = @app.frame(width, height).plain_lines.join("\n")

  def test_typing_goes_to_the_input_while_its_panel_has_focus
    @app.init
    @app.press("a", "q", "b")

    assert_equal "aqb", @app.component(:query).value
    assert_equal "aqb", R2UI::Context.new(@app).input_value(:query)
    assert_match(/│\? aqb/, text)
  end

  def test_options_reach_the_bubbles_model
    model = @app.component(:query)

    assert_kind_of Bubbles::TextInput, model
    assert_equal ["filter…", "? ", 20, 5], [model.placeholder, model.prompt, model.width, model.char_limit]
    @app.init
    @app.press("1", "2", "3", "4", "5", "6")
    assert_equal "12345", model.value, "char_limit"
  end

  def test_enter_calls_on_submit_with_the_value
    @app.init
    @app.press("h", "i", :enter)

    assert_equal "hi", @app.state[:submitted]
    assert @app.component(:query).focused?, "enter keeps the input focused"
  end

  def test_escape_blurs_and_enter_on_its_panel_refocuses
    @app.init
    @app.press("x", :escape)

    refute @app.component(:query).focused?
    assert_kind_of Bubbletea::QuitCommand, @app.press("q").first, "a blurred input leaves keys to the core"
    assert_equal "x", @app.component(:query).value

    @app.press(:enter)
    assert @app.component(:query).focused?
    assert_nil @app.state[:submitted], "refocusing doesn't submit"
    @app.press("y")
    assert_equal "xy", @app.component(:query).value
  end

  def test_keys_go_to_the_core_when_another_panel_has_focus
    @app.init
    @app.press(:tab)

    refute @app.component(:query).focused?
    @app.press("z", :enter)
    assert_equal "", @app.component(:query).value
    assert_nil @app.state[:submitted]
    refute @app.component(:query).focused?, "enter on another panel doesn't focus the input"
  end

  def test_view_matches_bubbles
    @app.init
    @app.press("a", "b")
    expected = Bubbles::TextInput.new
    expected.placeholder = "filter…"
    expected.prompt = "? "
    expected.width = 20
    expected.char_limit = 5
    expected.focus
    expected.value = "ab"

    assert_equal expected.view, @app.component(:query).view
    plain = expected.view.gsub(/\e\[[0-9;]*m/, "").rstrip

    assert_includes text, "│#{plain}"
  end

  def test_placeholder_shows_when_empty
    assert_match(/filter…/, text)
  end

  def test_needs_a_name
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { row { panel(:p, resource: nil) { text_input nil } } } }
  end
end
