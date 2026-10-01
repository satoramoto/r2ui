# frozen_string_literal: true

# A bubbles List in a panel: arrows move, `/` filters, enter picks.
#   exe/r2ui examples/dsl/list.rb

FRUITS = %w[apple apricot banana blackberry cherry damson elderberry fig grape kiwi lemon lime mango
            nectarine orange papaya pear plum quince raspberry strawberry tangerine].freeze

R2UI.dashboard do
  title "Fruit"

  row do
    panel :fruit, resource: nil do
      list :fruit, items: -> { FRUITS }, title: "Pick a fruit",
                   on_select: ->(fruit) { state[:picked] = fruit }
    end
    panel :picked, resource: nil do
      view { state[:picked] ? "You picked #{state[:picked]}." : "Nothing picked yet." }
    end
  end
end
