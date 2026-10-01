# frozen_string_literal: true

require "test_helper"

# s21-text-area: `text_area :name, placeholder:, height:` hosts a Bubbles::TextArea in a panel.
class TextAreaTest < Minitest::Test
  def setup
    R2UI.reset!
    R2UI.dashboard do
      row height: 8 do
        panel :notes, resource: nil do
          text_area :notes, placeholder: "write here", height: 4
        end
      end
      row height: 3 do
        panel :echo, resource: nil do
          view { "echo=#{area_value(:notes).inspect}" }
        end
      end
    end
    @app = R2UI::App.new(R2UI.registry)
    @app.init
  end

  def teardown = @app&.stop

  def text(width = 40, height = 14) = @app.frame(width, height).plain_lines.join("\n")

  def test_hosts_a_bubbles_text_area
    assert_kind_of Bubbles::TextArea, @app.component(:notes)
  end

  def test_shows_the_placeholder_while_empty
    assert_match(/write here/, text)
  end

  def test_area_value_is_empty_before_typing
    assert_equal "", @app.component(:notes).value
    assert_match(/echo=""/, text)
  end

  def test_typing_goes_to_the_area_while_its_panel_has_focus
    @app.press("h", "i")

    assert_equal "hi", @app.component(:notes).value
    assert_match(/echo="hi"/, text)
    refute_match(/write here/, text)
  end

  def test_enter_adds_a_line
    @app.press("a", :enter, "b")

    assert_equal "a\nb", @app.component(:notes).value
    assert_match(/echo="a\\nb"/, text)
  end

  def test_escape_blurs_the_area_and_keys_go_back_to_the_core
    @app.press("a", :escape)

    refute @app.component(:notes).focused?

    @app.press("b")

    assert_equal "a", @app.component(:notes).value
  end

  def test_the_area_is_sized_to_the_panel
    text(40, 14)

    assert_equal 4, @app.component(:notes).height
    assert_operator @app.component(:notes).width, :<=, 38
    assert_operator @app.component(:notes).width, :>, 0
  end

  def test_needs_a_name
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { row { panel(:p, resource: nil) { text_area } } } }
  end
end
