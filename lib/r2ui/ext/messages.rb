# frozen_string_literal: true

# s04-messages: your own messages and events, like a Bubbletea model's `update` cases.
#
#   class Deployed < Bubbletea::Message
#     attr_reader :name
#     def initialize(name) = (super(); @name = name)
#   end
#
#   R2UI.dashboard do
#     on Deployed do |msg|                         # any Bubbletea::Message subclass
#       state[:last] = msg.name
#     end
#     on :poll do |payload|                        # an event sent with `emit`
#       state[:polls] = state[:polls].to_i + 1
#       -> { Deployed.new(fetch_latest) }          # a Proc command runs in the background;
#     end                                          # the message it returns reaches `on Deployed`
#     every 5 do emit :poll end                    # emit(name, payload = nil, delay: 0)
#   end
#
# `on(matcher) { |msg| }` handles every message `matcher === msg` (a class, a lambda, ...); a
# Symbol handles the events `emit` sends with that name, and its block gets the payload. Handlers
# run on a Context (state, flash, quit, command, ...), in the order they were declared; the first
# that matches handles the message (call `pass` to let the next one see it), and a command it
# returns or enqueues runs. They are ordinary bindings: a focused component and higher-priority
# handlers see keys first, and messages nobody handles go on to the core.
#
# `emit(name, payload = nil, delay: 0)` (any block) enqueues `Bubbletea.send_message` with the
# event, after `delay` seconds; it returns the command. Events nobody handles are ignored, and an
# app ignores events another app emitted.
module R2UI
  module Ext
    module Messages
      # What `on` declares on the dashboard.
      Handler = Data.define(:matcher, :block) do
        def match?(message)
          return message.name == matcher if matcher.is_a?(Symbol) && message.is_a?(Event)

          matcher === message # rubocop:disable Style/CaseEquality
        end

        def argument(message) = matcher.is_a?(Symbol) ? message.payload : message
      end

      # The message `emit` sends. `app` scopes it to the app that emitted it.
      class Event < Bubbletea::Message
        attr_reader :name, :payload, :app

        def initialize(name:, payload:, app:)
          super()
          @name = name
          @payload = payload
          @app = app
        end
      end
    end
  end

  extension :messages do
    dsl :dashboard do
      def on(matcher, &block)
        raise ArgumentError, "on needs a block" unless block

        declare(:on, Ext::Messages::Handler.new(matcher:, block:))
      end
    end

    helpers do
      def emit(name, payload = nil, delay: 0)
        raise ArgumentError, "emit needs an event name" unless name.is_a?(Symbol) || name.is_a?(String)

        event = Ext::Messages::Event.new(name: name.to_sym, payload:, app:)
        command(Bubbletea.send_message(event, delay:))
      end
    end

    on Bubbletea::Message do |message|
      own_event = message.is_a?(Ext::Messages::Event) && message.app.equal?(app)
      pass if message.is_a?(Ext::Messages::Event) && !own_event

      handled = dashboard.declared(:on).any? do |handler|
        handler.match?(message) && handle(handler.block, handler.argument(message))
      end
      pass unless handled || own_event
    end
  end
end
