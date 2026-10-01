# frozen_string_literal: true

require_relative "helper"

# Issue #18: schedule_tick runs on batch/command threads while process_ticks runs on the
# main loop. Ticks scheduled between process_ticks reading and replacing the pending list
# must not be lost.
class TickRaceTest < Minitest::Test
  # The GVL makes the race window tiny, so this list yields inside partition to force a
  # thread switch exactly where process_ticks used to be unprotected.
  class YieldingList < Array
    def partition(&)
      super.tap { Thread.pass }.map { |part| YieldingList.new(part) }
    end
  end

  class CountingModel
    include Bubbletea::Model

    attr_reader :count

    def initialize
      @count = 0
    end

    def update(_message)
      @count += 1
      [self, nil]
    end

    def view
      ""
    end
  end

  def test_no_tick_lost_when_scheduling_from_many_threads
    model = CountingModel.new
    runner = Bubbletea::Runner.new(model)
    runner.instance_variable_set(:@running, true)
    runner.instance_variable_set(:@pending_ticks, YieldingList.new)
    threads_count = 4
    per_thread = 500
    done = false

    processor = Thread.new do
      until done
        runner.__send__(:process_ticks)
        Thread.pass
      end
    end
    schedulers = Array.new(threads_count) do
      Thread.new do
        per_thread.times do
          runner.__send__(:schedule_tick, Bubbletea::TickCommand.new(0) { :tick })
          Thread.pass
        end
      end
    end
    schedulers.each(&:join)
    done = true
    processor.join
    runner.__send__(:process_ticks)

    assert_equal threads_count * per_thread, model.count
  end
end
