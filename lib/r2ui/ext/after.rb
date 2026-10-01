# frozen_string_literal: true

# s06-after: a one-shot delay (a single Bubbletea tick).
#
#   R2UI.dashboard do
#     every 60 do
#       state[:banner] = "syncing…"
#       after 3 do                    # seconds, or anything with #to_f
#         state[:banner] = nil        # runs once, 3 s later, on the update thread
#         flash "synced"              # any Context helper; a returned command runs too
#       end
#     end
#   end
#
# `after` is a helper, so it works from any block: a key binding, a timer, an `on` handler, a
# component callback. Each call schedules its own one-shot; a later `after` never cancels an
# earlier one. It returns the Bubbletea command (already enqueued). The delay may be 0 (run on the
# next update); a negative delay or a missing block raises.
module R2UI
  module Ext
    module After
      # The message a one-shot delivers. `app` scopes it to the app that scheduled it.
      class Fire < Bubbletea::Message
        attr_reader :block, :app

        def initialize(block:, app:)
          super()
          @block = block
          @app = app
        end
      end
    end
  end

  extension :after do
    helpers do
      def after(seconds, &block)
        raise ArgumentError, "after needs a block" unless block

        seconds = seconds.to_f
        raise ArgumentError, "after needs a non-negative delay, got #{seconds}" if seconds.negative?

        target = app
        command(Bubbletea.tick(seconds) { Ext::After::Fire.new(block:, app: target) })
      end
    end

    on Ext::After::Fire do |fire|
      pass unless fire.app.equal?(app)

      call(fire.block)
    end
  end
end
