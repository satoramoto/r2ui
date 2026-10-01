# frozen_string_literal: true

# s05-state: declared initial state (a Bubbletea model's starting fields).
#
#   R2UI.dashboard do
#     state count: 0, log: []
#     state theme: :dark                  # a second call merges (later keys win)
#
#     every 1 do state[:count] += 1 end
#   end
#
# The declared values seed the app's `state` Hash in `setup`, before init and before any frame,
# so snapshots and the first frame see them. Each app gets a deep copy (Hashes, Arrays and
# Strings are copied all the way down), so two apps never share the `log` array and mutating
# one app's state never changes the declaration.
module R2UI
  module Ext
    module State
      module_function

      # A copy of `value` whose Hashes, Arrays and unfrozen Strings are fresh objects.
      def deep_copy(value)
        case value
        when Hash then value.to_h { |k, v| [deep_copy(k), deep_copy(v)] }
        when Array then value.map { |v| deep_copy(v) }
        when String then value.frozen? ? value : value.dup
        else value
        end
      end
    end
  end

  extension :state do
    dsl :dashboard do
      def state(values = nil, **fields)
        values = (values || {}).merge(fields)
        declare(:state, Ext::State.deep_copy(values))
      end
    end

    setup do
      dashboard.declared(:state).each { |values| state.merge!(Ext::State.deep_copy(values)) }
    end
  end
end
