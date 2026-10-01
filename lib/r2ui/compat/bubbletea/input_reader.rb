# frozen_string_literal: true

module R2UI
  module Compat
    module Tea
      # Upstream's InputReader (go/input.go): a background reader that pushes raw chunks of up to 256
      # bytes onto a queue. Go reads through cancelreader so that a stopped reader no longer consumes
      # stdin; here the thread waits with IO.select on a short timeout and checks a stop flag, and
      # only reads once the input is readable. EOF or a read error ends the thread.
      class InputReader
        CHUNK = 256
        WAIT = 0.02

        attr_reader :queue

        def initialize(io)
          @io = io
          @queue = Thread::Queue.new
          @stop = false
          @thread = nil
        end

        def start
          @thread ||= Thread.new do
            Thread.current.report_on_exception = false
            Thread.current.name = "bubbletea input reader"
            read_loop
          end
          self
        end

        def running? = !@thread.nil? && !@stop

        # Stop consuming input. With wait, joins the thread (it notices the flag within WAIT seconds);
        # a thread stuck in a read after all is killed rather than left to steal a child's input.
        def stop(wait: true)
          @stop = true
          thread = @thread
          return unless thread && wait && thread != Thread.current

          thread.kill unless thread.join(WAIT * 10)
          nil
        end

        # One chunk, or nil when none arrives within timeout_ms.
        def pop(timeout_ms)
          timeout = timeout_ms.to_i <= 0 ? 0 : timeout_ms / 1000.0
          @queue.pop(timeout: timeout)
        end

        private

        def read_loop
          until @stop
            ready = IO.select([@io], nil, nil, WAIT)
            next unless ready && !@stop

            @queue << @io.readpartial(CHUNK)
          end
        rescue EOFError, IOError, SystemCallError
          nil
        end
      end
    end
  end
end
