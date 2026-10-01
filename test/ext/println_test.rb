# frozen_string_literal: true

require "test_helper"

# s11-println: `println(text)` enqueues Bubbletea's PutsCommand and returns it. The helper is
# reached through an `every` block, the only way to run a block on a Context without a key story.
class PrintlnTest < Minitest::Test
  def setup = R2UI.reset!

  # Builds an app whose first timer tick runs `block`; returns [app, the command the tick yields].
  def fire(&block)
    R2UI.dashboard { every(1, &block) }
    app = R2UI::App.new(R2UI.registry)
    _, init = app.init
    tick = init.is_a?(Bubbletea::BatchCommand) ? init.commands.first : init
    _, out = app.update(tick.callback.call)
    [app, out]
  end

  def puts_commands(out)
    commands = out.is_a?(Bubbletea::BatchCommand) ? out.commands : [out]
    commands.grep(Bubbletea::PutsCommand)
  end

  def test_println_enqueues_a_puts_command_with_the_text
    app, out = fire { println "deployed" }

    assert_equal ["deployed"], puts_commands(out).map(&:text)
  ensure
    app&.stop
  end

  def test_println_returns_the_command_it_enqueued
    returned = nil
    app, out = fire { returned = println("hello") }

    assert_kind_of Bubbletea::PutsCommand, returned
    assert_equal "hello", returned.text
    assert(puts_commands(out).any? { |c| c.equal?(returned) })
  ensure
    app&.stop
  end

  def test_a_block_may_just_return_the_command
    app, out = fire { println "last value" }

    assert_equal 1, puts_commands(out).size
  ensure
    app&.stop
  end

  def test_each_call_enqueues_its_own_line_in_order
    app, out = fire do
      println "one"
      println "two"
    end

    assert_equal %w[one two], puts_commands(out).map(&:text)
  ensure
    app&.stop
  end

  def test_println_matches_bubbletea_puts
    app, out = fire { println "same" }

    expected = Bubbletea.puts("same")
    actual = puts_commands(out).first
    assert_equal expected.class, actual.class
    assert_equal expected.text, actual.text
  ensure
    app&.stop
  end
end
