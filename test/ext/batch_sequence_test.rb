# frozen_string_literal: true

require "test_helper"

# s07-batch-sequence: `batch { }` and `sequence { }` group the commands a block enqueues.
class BatchSequenceTest < Minitest::Test
  def setup = R2UI.reset!

  # Builds an app whose one timer runs `block` on a Context, fires it once, and returns
  # [what the block returned (state[:result]), what update returned].
  def run_block(&block)
    R2UI.dashboard do
      every(5) { state[:result] = instance_exec(&block) }
    end
    app = R2UI::App.new(R2UI.registry)
    _, init_command = app.init
    tick = init_command.is_a?(Bubbletea::TickCommand) ? init_command : init_command.commands.first
    _, out = app.update(tick.callback.call)
    [app.state[:result], out]
  ensure
    app&.stop
  end

  def commands_of(out) = out.is_a?(Bubbletea::BatchCommand) ? out.commands : [out]

  def test_batch_groups_enqueued_commands_into_one_bubbletea_batch
    result, out = run_block do
      batch do
        command(Bubbletea.send_message(:a))
        command(Bubbletea.send_message(:b))
      end
    end

    assert_kind_of Bubbletea::BatchCommand, result
    assert_equal %i[a b], result.commands.map(&:message)
    assert_includes commands_of(out), result
  end

  def test_sequence_groups_enqueued_commands_into_one_bubbletea_sequence_in_order
    result, = run_block do
      sequence do
        command(Bubbletea.send_message(:first))
        command(Bubbletea.send_message(:second))
        quit
      end
    end

    assert_kind_of Bubbletea::SequenceCommand, result
    assert_equal [Bubbletea::SendMessage, Bubbletea::SendMessage, Bubbletea::QuitCommand], result.commands.map(&:class)
    assert_equal %i[first second], result.commands.first(2).map(&:message)
  end

  def test_grouped_commands_are_not_also_run_on_their_own
    _, out = run_block do
      sequence { command(Bubbletea.send_message(:inner)) }
    end

    refute(commands_of(out).any?(Bubbletea::SendMessage), "the inner command only runs inside the sequence")
    assert(commands_of(out).any?(Bubbletea::SequenceCommand))
  end

  def test_nesting_works
    result, = run_block do
      sequence do
        command(Bubbletea.send_message(:before))
        batch do
          command(Bubbletea.send_message(:x))
          command(Bubbletea.send_message(:y))
        end
      end
    end

    assert_kind_of Bubbletea::SequenceCommand, result
    before, inner = result.commands
    assert_equal :before, before.message
    assert_kind_of Bubbletea::BatchCommand, inner
    assert_equal %i[x y], inner.commands.map(&:message)
  end

  def test_empty_block_enqueues_nothing
    _, out = run_block { batch { nil } }
    assert_equal [Bubbletea::TickCommand], commands_of(out).map(&:class)

    _, out = run_block { sequence { nil } }
    assert_equal [Bubbletea::TickCommand], commands_of(out).map(&:class)
  end

  def test_commands_a_block_returns_are_grouped_too
    result, = run_block { batch { Bubbletea.send_message(:returned) } }

    assert_equal [:returned], result.commands.map(&:message)
  end
end
