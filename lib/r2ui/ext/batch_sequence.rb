# frozen_string_literal: true

# s07-batch-sequence: command composition (Bubbletea.batch / Bubbletea.sequence, as blocks).
#
#   R2UI.dashboard do
#     on_key "d", help: "deploy" do
#       sequence do                        # in order; stops at quit
#         flash "deploying"
#         command(-> { Deploy.run })       # any command a helper enqueues, or the block returns
#         batch do                         # concurrently
#           command(-> { Slack.notify })
#           command(-> { Metrics.bump })
#         end
#       end
#     end
#   end
#
# `batch { }` groups every command enqueued inside the block (by `command`, `quit`, any command
# helper, or the block's return value) into one Bubbletea.batch; `sequence { }` into one
# Bubbletea.sequence. The grouped commands don't also run on their own. Blocks nest. Each returns
# the grouped command (already enqueued), or nil if the block enqueued nothing.
module R2UI
  module Ext
    module BatchSequence
      module_function

      # Runs `block` on `context` with an empty command list, then enqueues what it collected as
      # one command built by `combine` (Bubbletea.batch or Bubbletea.sequence).
      def group(context, combine, block)
        raise ArgumentError, "#{combine} needs a block" unless block

        collected = context.instance_variable_get(:@commands)
        context.instance_variable_set(:@commands, [])
        begin
          context.call(block)
          inner = context.instance_variable_get(:@commands)
        ensure
          context.instance_variable_set(:@commands, collected)
        end
        return nil if inner.empty?

        context.command(Bubbletea.public_send(combine, *inner))
      end
    end
  end

  extension :batch_sequence do
    helpers do
      def batch(&block) = Ext::BatchSequence.group(self, :batch, block)

      def sequence(&block) = Ext::BatchSequence.group(self, :sequence, block)
    end
  end
end
