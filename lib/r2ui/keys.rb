# frozen_string_literal: true

module R2UI
  # Splits raw terminal input into key names (:up, :tab, "q", ...).
  module Keys
    SEQUENCES = {
      "\e[A" => :up, "\e[B" => :down, "\e[C" => :right, "\e[D" => :left,
      "\e[5~" => :page_up, "\e[6~" => :page_down, "\e[H" => :home, "\e[F" => :end,
      "\e[Z" => :back_tab, "\t" => :tab, "\r" => :enter, "\n" => :enter,
      "\x7F" => :backspace, "\b" => :backspace, "\x03" => :interrupt, "\e" => :escape
    }.freeze
    PATTERN = Regexp.union(*SEQUENCES.keys.sort_by { -_1.length }, /./m)

    module_function

    def parse(input) = input.scan(PATTERN).map { |k| SEQUENCES.fetch(k, k) }
  end
end
