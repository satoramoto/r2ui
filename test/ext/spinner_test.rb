# frozen_string_literal: true

require "test_helper"

# s25-spinner: `spinner` hosts a Bubbles::Spinner. Expected frames and tick intervals come from
# bubbles itself (Bubbles::Spinners), never hand-written.
class SpinnerTest < Minitest::Test
  def setup
    R2UI.reset!
    R2UI::Component.require_bubbles!
  end

  def teardown = @app&.stop

  def build(**options)
    R2UI.dashboard do
      row height: 3 do
        panel :work, resource: nil do
          spinner :busy, **options
        end
      end
    end
    @app = R2UI::App.new(R2UI.registry)
  end

  def text(width = 30, height = 6) = @app.frame(width, height).plain_lines.join("\n")

  def ticks(command) = command.is_a?(Bubbletea::BatchCommand) ? command.commands : [command]

  def spinner_tick(command) = ticks(command).find { |c| c.is_a?(Bubbletea::TickCommand) }

  def test_draws_the_first_frame_of_the_default_style
    build
    assert_includes text, Bubbles::Spinners::DOT[:frames].first
  end

  def test_style_picks_any_bubbles_spinner
    build(style: :globe)
    assert_includes text, Bubbles::Spinners::GLOBE[:frames].first
    refute_includes text, Bubbles::Spinners::DOT[:frames].first
  end

  def test_label_is_drawn_after_the_spinner
    build(label: "Loading")
    assert_match(/#{Regexp.escape(Bubbles::Spinners::DOT[:frames].first)}\s*Loading/, text)
  end

  def test_init_starts_the_spinner_ticking_at_its_fps
    build
    _, command = @app.init

    tick = spinner_tick(command)
    refute_nil tick, "init should return the spinner's tick"
    assert_in_delta Bubbles::Spinners::DOT[:fps], tick.duration, 1e-9
  end

  def test_a_tick_advances_the_frame_and_schedules_the_next
    build
    _, command = @app.init

    _, next_command = @app.update(spinner_tick(command).callback.call)

    assert_includes text, Bubbles::Spinners::DOT[:frames][1]
    refute_nil spinner_tick(next_command), "each tick schedules the next"
  end

  def test_frames_wrap_around
    build(style: :moon)
    frames = Bubbles::Spinners::MOON[:frames]
    _, command = @app.init
    tick = spinner_tick(command)

    frames.size.times do
      _, command = @app.update(tick.callback.call)
      tick = spinner_tick(command)
    end

    assert_includes text, frames.first
  end

  def test_two_spinners_animate_independently
    R2UI.dashboard do
      row height: 3 do
        panel(:a, resource: nil) { spinner :one, style: :moon }
        panel(:b, resource: nil) { spinner :two, style: :moon }
      end
    end
    @app = R2UI::App.new(R2UI.registry)
    _, command = @app.init
    first = ticks(command).select { |c| c.is_a?(Bubbletea::TickCommand) }.first

    @app.update(first.callback.call)

    frames = Bubbles::Spinners::MOON[:frames]
    out = text(40, 6)
    assert_equal 1, out.scan(frames[1]).size
  end

  def test_while_false_shows_nothing
    flag = false
    build(label: "Loading", while: -> { flag })
    refute_match(/Loading/, text)
    refute_includes text, Bubbles::Spinners::DOT[:frames].first

    flag = true
    assert_match(/Loading/, text)
    assert_includes text, Bubbles::Spinners::DOT[:frames].first
  end

  def test_unknown_style_raises
    assert_raises(ArgumentError) { build(style: :nope) }
  end
end
