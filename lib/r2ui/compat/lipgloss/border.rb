# frozen_string_literal: true

# Border type names, same as lipgloss-ruby 0.2.2 lib/lipgloss/border.rb (MIT). The border glyphs and
# how they are drawn live in style/border.rb.
module Lipgloss
  module Border
    NORMAL = :normal
    ROUNDED = :rounded
    THICK = :thick
    DOUBLE = :double
    ASCII = :ascii
    HIDDEN = :hidden
    BLOCK = :block
    OUTER_HALF_BLOCK = :outer_half_block
    INNER_HALF_BLOCK = :inner_half_block
  end
end
