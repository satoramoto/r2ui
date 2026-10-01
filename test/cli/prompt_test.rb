# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"

# Prompt::Model, the base every prompt story builds on: ctrl+c/esc cancel there, and a hosted
# component gets its init and every message the prompt doesn't handle itself.
class CLIPromptModelTest < Minitest::Test
  include R2UI::CLI::Testing
  K = Bubbletea::KeyMessage

  # A bubbles-style component: init/update return [model, cmd] and update returns a new model.
  class Echo
    attr_reader :seen

    def initialize(seen = []) = @seen = seen

    def init = [self, :blink]

    def update(message) = [Echo.new(seen + [message]), :"cmd_#{seen.size}"]
  end

  # Answers on enter with whatever the component saw; leaves every other key to it.
  class Asker < R2UI::CLI::Prompt::Model
    def initialize(shell)
      super
      self.component = Echo.new
    end

    def view = "? Name"

    private

    def key(name, _message) = name == "enter" ? submit(component.seen.size) : nil
  end

  def rune(char) = K.new(key_type: K::KEY_RUNES, runes: [char.ord])

  def test_init_runs_the_components_init
    model = Asker.new(test_shell)
    assert_equal [model, :blink], model.init
  end

  def test_unhandled_keys_and_other_messages_reach_the_component
    model = Asker.new(test_shell)
    _, command = model.update(rune("a"))
    assert_equal :cmd_0, command
    tick = Bubbletea::WindowSizeMessage.new(width: 80, height: 24)
    _, command = model.update(tick)
    assert_equal :cmd_1, command
    assert_equal ["a", tick], [model.component.seen.first.to_s, model.component.seen.last]
  end

  def test_keys_the_prompt_handles_dont_reach_the_component
    model = Asker.new(test_shell)
    model.update(rune("a"))
    model.update(K.new(key_type: K::KEY_ENTER))
    assert model.done?
    assert_equal 1, model.value
    assert_equal 1, model.component.seen.size
  end

  def test_ctrl_c_and_esc_cancel_without_reaching_the_component
    [K::KEY_CTRL_C, K::KEY_ESC].each do |type|
      model = Asker.new(test_shell)
      model.update(K.new(key_type: type))
      assert model.interrupted?
      assert_empty model.component.seen
    end
  end

  def test_a_prompt_without_a_component_ignores_other_messages
    model = Class.new(R2UI::CLI::Prompt::Model) { def view = "" }.new(test_shell)
    assert_equal [model, nil], model.init
    assert_equal [model, nil], model.update(rune("x"))
  end
end
