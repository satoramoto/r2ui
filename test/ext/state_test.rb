# frozen_string_literal: true

require "test_helper"

# s05-state: declared initial state, seeded in setup.
class StateTest < Minitest::Test
  def setup = R2UI.reset!

  def test_state_seeds_app_state_before_any_frame
    R2UI.dashboard do
      state count: 0, log: []
    end
    app = R2UI::App.new(R2UI.registry)

    assert_equal({ count: 0, log: [] }, app.state)
  end

  def test_first_frame_sees_the_seeded_state
    R2UI.dashboard do
      state count: 7
      row do
        panel :counter, resource: nil do
          view { "count: #{state[:count]}" }
        end
      end
    end
    app = R2UI::App.new(R2UI.registry)

    assert_match(/count: 7/, app.frame(40, 5).plain_lines.join("\n"))
  end

  def test_values_are_deep_copied_per_app
    R2UI.dashboard do
      state log: [], nested: { items: [] }
    end
    one = R2UI::App.new(R2UI.registry)
    two = R2UI::App.new(R2UI.registry)

    one.state[:log] << "x"
    one.state[:nested][:items] << 1

    assert_equal [], two.state[:log]
    assert_equal [], two.state[:nested][:items]
    refute_same one.state[:log], two.state[:log]
  end

  def test_mutating_app_state_does_not_change_the_declaration
    R2UI.dashboard do
      state log: []
    end
    R2UI::App.new(R2UI.registry).state[:log] << "x"

    assert_equal [], R2UI::App.new(R2UI.registry).state[:log]
  end

  def test_calling_state_twice_merges
    R2UI.dashboard do
      state count: 0, log: []
      state count: 5, extra: true
    end
    app = R2UI::App.new(R2UI.registry)

    assert_equal({ count: 5, log: [], extra: true }, app.state)
  end

  def test_no_state_declaration_leaves_state_empty
    R2UI.dashboard { title "Plain" }

    assert_equal({}, R2UI::App.new(R2UI.registry).state)
  end
end
