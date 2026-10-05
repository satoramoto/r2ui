# frozen_string_literal: true

require "test_helper"
require "r2ui/compat/bubbletea/renderer"

# r2ui additions to the Runner: a model with `frame_due?` (R2UI::App) is drawn only in frame slots
# where it says so, a resize always repaints, and `synchronized:` reaches the renderer.
class CompatFrameGatingTest < Minitest::Test
  Tea = R2UI::Compat::Tea

  # Stands in for Bubbletea::Program: no terminal, a real renderer writing to a StringIO. Each
  # poll sleeps a little and calls `on_poll` with the poll count.
  class FakeProgram
    attr_reader :renders, :output
    attr_accessor :size, :on_poll

    def initialize
      @renders = 0
      @polls = 0
      @output = StringIO.new
      @size = [80, 24]
    end

    def create_renderer = Tea.register_renderer(Tea::Renderer.new(@output))

    def render(id, view)
      @renders += 1
      Tea.renderer(id).render(view)
    end

    def terminal_size = @size

    def poll_event(_timeout)
      sleep 0.002
      @polls += 1
      on_poll&.call(@polls)
      nil
    end

    def renderer_set_size(*) = nil
    def renderer_set_alt_screen(*) = nil
    def method_missing(*) = nil
    def respond_to_missing?(*) = true
  end

  class Model
    attr_accessor :due, :updates

    def initialize(due) = (@due = due; @updates = 0)
    def init = [self, nil]
    def update(_message) = (@updates += 1; [self, nil])
    def view = "frame"
    def frame_due? = @due
  end

  class PlainModel
    def init = [self, nil]
    def update(_message) = [self, nil]
    def view = "frame"
  end

  # Runs the model for `polls` loop turns at 1000 fps (every turn is a frame slot).
  def drive(model, polls: 20, **options, &on_poll)
    program = FakeProgram.new
    runner = Bubbletea::Runner.new(model, alt_screen: true, fps: 1000, **options)
    runner.instance_variable_set(:@program, program)
    program.on_poll = lambda do |n|
      on_poll&.call(n, runner, program)
      runner.instance_variable_set(:@running, false) if n >= polls
    end
    runner.run
    program
  end

  def test_models_without_frame_due_draw_every_slot
    assert_operator drive(PlainModel.new).renders, :>=, 12
  end

  def test_frame_slots_draw_only_when_due
    assert_equal 2, drive(Model.new(false)).renders, "only the first and the last frame"
    assert_operator drive(Model.new(true)).renders, :>=, 12
  end

  def test_a_resize_repaints_even_when_not_due
    program = drive(Model.new(false)) do |n, runner, prog|
      next unless n == 5

      prog.size = [100, 30]
      runner.instance_variable_set(:@resize_pending, true)
    end
    assert_equal 3, program.renders
  end

  def test_synchronized_option_reaches_the_renderer
    assert_includes drive(Model.new(false), synchronized: true).output.string, "\e[?2026h"
    refute_includes drive(Model.new(false)).output.string, "\e[?2026h"
  end
end
