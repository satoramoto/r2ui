# frozen_string_literal: true

require "test_helper"

# s03-keys: `on_key` binds core or Bubbletea key names on a dashboard.
class KeysTest < Minitest::Test
  # A Bubbletea-style model that takes typed text, standing in for a focused component.
  class Field
    attr_reader :value

    def initialize = @value = +""
    def init = [self, nil]
    def focus = nil
    def blur = nil
    def view = "[#{@value}]"

    def update(message)
      @value << message.char if message.is_a?(Bubbletea::KeyMessage) && message.runes?
      [self, nil]
    end
  end

  FieldItem = Data.define(:name)

  def setup
    R2UI.reset!
    Fixtures.define_processes
  end

  def teardown = R2UI::Extensions.remove(:test_keys_field)

  def build(&block)
    R2UI.dashboard do
      instance_eval(&block) if block
      row { panel :process }
    end
    @app = R2UI::App.new(R2UI.registry)
    @app.snapshot(width: 100, height: 20)
    @app
  end

  def text(app, width = 100, height = 20) = app.frame(width, height).plain_lines.join("\n")

  def test_binds_a_typed_key_and_runs_the_block_on_a_context
    app = build { on_key("r") { state[:ran] = message.to_s } }

    app.press("r")

    assert_equal "r", app.state[:ran]
  end

  def test_binds_ctrl_function_and_named_keys
    app = build do
      on_key("ctrl+r") { state[:ctrl_r] = true }
      on_key(:f1) { state[:f1] = true }
      on_key("enter") { state[:enter] = true }
    end

    app.press("ctrl+r", :f1, :enter)

    assert_equal [true, true, true], app.state.values_at(:ctrl_r, :f1, :enter)
  end

  def test_one_binding_can_take_several_keys
    app = build { on_key("a", "ctrl+a") { state[:count] = state[:count].to_i + 1 } }

    app.press("a", "ctrl+a", "b")

    assert_equal 2, app.state[:count]
  end

  def test_returned_and_enqueued_commands_run
    app = build do
      on_key("x") { quit }
      on_key("y") { Bubbletea.quit }
    end

    assert_kind_of Bubbletea::QuitCommand, app.press("x").first
    assert_kind_of Bubbletea::QuitCommand, app.press("y").first
  end

  def test_binding_beats_the_core_key
    app = build { on_key("s") { state[:bound] = true } }
    assert_match(/sort: Cpu▼/, text(app))

    app.press("s")

    assert app.state[:bound]
    assert_match(/sort: Cpu▼/, text(app), "the core sort key did not run")
  end

  def test_unbound_core_keys_still_work
    app = build { on_key("r") { nil } }

    app.press("s")

    refute_match(/sort: Cpu▼/, text(app))
  end

  def test_binding_does_not_beat_the_search_prompt
    app = build { on_key("r") { state[:bound] = true } }

    app.press("/", "r")

    assert_nil app.state[:bound]
    assert_match(%r{/r}, text(app))
  end

  def test_binding_does_not_beat_the_confirm_prompt
    killed = []
    R2UI.registry.resource(:process).actions << R2UI::DSL::Action.new(
      name: :kill, label: "Kill", key: "K", confirm: true, handler: ->(p) { killed << p.pid }
    )
    app = build { on_key("y") { state[:bound] = true } }

    app.press("K", "y")

    assert_nil app.state[:bound]
    refute_empty killed, "y confirmed the action"
  end

  def test_binding_does_not_beat_a_focused_component
    R2UI.extension(:test_keys_field) do
      dsl(:panel) { def field(name) = item(FieldItem.new(name)) }
      component(FieldItem, focusable: true) { |_item| Field.new }
    end
    R2UI.dashboard do
      on_key("h") { state[:bound] = true }
      row { panel(:form, resource: nil) { field :name } }
      row { panel :process }
    end
    app = R2UI::App.new(R2UI.registry)
    app.focus = app.dashboard.panels.first
    app.init

    app.press("h")

    assert_nil app.state[:bound]
    assert_equal "h", app.component(:name).value

    app.press(:tab, "h")

    assert app.state[:bound], "once the component loses focus the binding runs"
  ensure
    app&.stop
  end

  def test_help_adds_a_status_bar_hint
    app = build do
      on_key("r", help: "refresh") { nil }
      on_key("z") { nil }
    end

    assert_includes app.hint_pairs, %w[r refresh]
    assert_equal 1, app.hint_pairs.count { |_key, label| label == "refresh" }
    assert_match(/r refresh/, text(app, 140, 20).lines.last)
    refute(app.hint_pairs.any? { |key, _| key == "z" }, "no help: no hint")
  end

  def test_binding_the_same_key_twice_in_one_dashboard_raises
    assert_raises(ArgumentError, R2UI::Error) do
      R2UI.dashboard(:bad) do
        on_key("r") { nil }
        on_key("r") { nil }
      end
    end
  end

  def test_needs_a_key_and_a_block
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { on_key { nil } } }
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { on_key("r") } }
  end
end
