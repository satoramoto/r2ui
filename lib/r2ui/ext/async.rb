# frozen_string_literal: true

# s08-async: background work (a Bubbletea Proc command, with its result routed back).
#
#   R2UI.dashboard do
#     every 30 do
#       async(-> { Net::HTTP.get(URI("https://example.com/status")) }) do |body, error|
#         if error
#           flash "status failed: #{error.message}"
#         else
#           state[:status] = body     # any Context helper; a returned command runs too
#         end
#       end
#     end
#   end
#
# `async(callable) { |value, error| }` is a helper, usable from any block (a timer, a key
# binding, a handler). The callable runs off the update thread, so the UI keeps drawing and taking
# keys meanwhile; it must not touch app state. When it finishes, the block runs on the update
# thread with its return value and nil, or with nil and the exception if it raised (StandardError).
# Returns the command (already enqueued). Results that arrive after the app has quit are dropped.
module R2UI
  module Ext
    module Async
      # The message a finished callable delivers. `app` scopes it to the app that started it.
      class Done < Bubbletea::Message
        attr_reader :app, :block, :value, :error

        def initialize(app:, block:, value:, error:)
          super()
          @app = app
          @block = block
          @value = value
          @error = error
        end
      end

      module_function

      # The Proc command the runner calls on its own thread; it returns the Done message.
      def command(app, callable, block)
        proc do
          Done.new(app:, block:, value: callable.call, error: nil)
        rescue StandardError => e
          Done.new(app:, block:, value: nil, error: e)
        end
      end

      # True if `command` quits the program (alone, or inside a batch or sequence).
      def quits?(command)
        case command
        when Bubbletea::QuitCommand then true
        when Bubbletea::BatchCommand, Bubbletea::SequenceCommand then command.commands.any? { |c| quits?(c) }
        else false
        end
      end
    end
  end

  extension :async do
    helpers do
      def async(callable, &block)
        raise ArgumentError, "async needs a callable, got #{callable.inspect}" unless callable.respond_to?(:call)
        raise ArgumentError, "async needs a block" unless block

        command(Ext::Async.command(app, callable, block))
      end
    end

    # Remember that this app quit, so late results are dropped.
    after_update do
      store(:async)[:quit] = true if Ext::Async.quits?(commands)
    end

    on Ext::Async::Done do |done|
      pass unless done.app.equal?(app)

      call(done.block, done.value, done.error) unless store(:async)[:quit]
    end
  end
end
