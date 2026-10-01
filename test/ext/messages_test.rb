# frozen_string_literal: true

require "test_helper"

# s04-messages: `on` handlers for your own Bubbletea messages and `emit`ted events.
class MessagesTest < Minitest::Test
  class Deployed < Bubbletea::Message
    attr_reader :name

    def initialize(name)
      super()
      @name = name
    end
  end

  class Unhandled < Bubbletea::Message; end

  def setup
    R2UI.reset!
    R2UI.dashboard do
      on(Deployed) do |msg|
        state[:deployed] = msg.name
        flash "deployed #{msg.name}"
      end
      on(:poll) { |payload| state[:polls] = (state[:polls] || []) << payload }
      on(:later) { |payload| emit(:poll, payload, delay: 2) }
      on(:stop) { quit }
      on(:fetch) { -> { Deployed.new("from the background") } }

      row do
        panel :log, resource: nil do
          view { "deployed: #{state[:deployed]}" }
        end
      end
    end
    @app = R2UI::App.new(R2UI.registry)
    @app.init
  end

  def teardown = @app.stop

  # The event message an `emit` returns, as the runner would deliver it.
  def deliver(command)
    assert_kind_of Bubbletea::SendMessage, command
    @app.update(command.message).last
  end

  def emit(name, payload = nil, **)
    ctx = R2UI::Context.new(@app)
    ctx.emit(name, payload, **)
  end

  def test_on_a_message_class_handles_it
    @app.update(Deployed.new("api"))

    assert_equal "api", @app.state[:deployed]
    assert_match(/deployed: api/, @app.frame(40, 5).plain_lines.join("\n"))
    assert_match(/deployed api/, @app.frame(40, 5).plain_lines.join("\n"))
  end

  def test_emit_sends_an_event_that_reaches_its_handler_with_the_payload
    command = emit(:poll, { n: 1 })

    assert_equal 0, command.delay
    deliver(command)

    assert_equal [{ n: 1 }], @app.state[:polls]
  end

  def test_emit_with_a_delay_uses_send_message_with_that_delay
    command = emit(:poll, :late, delay: 3)

    assert_kind_of Bubbletea::SendMessage, command
    assert_equal 3, command.delay
  end

  def test_handlers_commands_run
    later = deliver(emit(:later, :x))

    assert_kind_of Bubbletea::SendMessage, later
    assert_equal 2, later.delay
    deliver(later)
    assert_equal [:x], @app.state[:polls]

    assert_kind_of Bubbletea::QuitCommand, deliver(emit(:stop))
  end

  def test_a_message_from_a_background_proc_command_reaches_its_handler
    background = deliver(emit(:fetch))

    assert_kind_of Proc, background
    @app.update(background.call)

    assert_equal "from the background", @app.state[:deployed]
  end

  def test_unknown_events_and_unhandled_messages_are_ignored
    assert_nil deliver(emit(:nobody_listens, 1))
    _, command = @app.update(Unhandled.new)

    assert_nil command
    assert_nil @app.state[:polls]
  end

  def test_keys_still_reach_the_core
    assert_kind_of Bubbletea::QuitCommand, @app.press("q").last
  end

  def test_events_of_another_app_are_ignored
    other = R2UI::App.new(R2UI.registry)
    other.init
    command = R2UI::Context.new(other).emit(:poll, 1)

    @app.update(command.message)

    assert_nil @app.state[:polls]
  ensure
    other&.stop
  end

  def test_on_needs_a_block_and_emit_needs_a_name
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { on(:x) } }
    assert_raises(ArgumentError) { emit(nil) }
  end
end
