# frozen_string_literal: true

LipglossCases.define("layout") do
  positions = {
    "top" => ":top", "center" => ":center", "bottom" => ":bottom", "left" => ":left", "right" => ":right",
    "f02" => "0.2", "f08" => "0.8", "int0" => "0", "int1" => "1", "str_bottom" => %q{"bottom"},
    "const_center" => "Lipgloss::CENTER", "over" => "1.5", "under" => "-0.5"
  }

  # --- join_horizontal ------------------------------------------------------------------------------
  positions.each do |name, pos|
    add "layout.join_h_#{name}", %{Lipgloss.join_horizontal(#{pos}, "a\\nb\\nc", "X", "1\\n2")}
    add "layout.join_v_#{name}", %{Lipgloss.join_vertical(#{pos}, "abc", "X", "12\\n1234")}
  end
  add "layout.join_h_single", %q{Lipgloss.join_horizontal(:top, "a\nb")}
  add "layout.join_h_none", %q{Lipgloss.join_horizontal(:top)}
  add "layout.join_h_empty_strings", %q{Lipgloss.join_horizontal(:top, "", "")}
  add "layout.join_h_uneven_width", %q{Lipgloss.join_horizontal(:top, "a\nbbbb", "cc\nd\ne")}
  add "layout.join_h_styled", %q{a = Lipgloss::Style.new.border(:normal).render("A"); b = Lipgloss::Style.new.border(:rounded).padding(1).render("B"); Lipgloss.join_horizontal(:center, a, b)}
  add "layout.join_h_ansi", %q{Lipgloss.join_horizontal(:bottom, "\e[31mred\e[0m\nx", "\e[1mb\e[0m")}
  add "layout.join_h_wide", %q{Lipgloss.join_horizontal(:top, "日本\n語", "ab\ncd")}
  add "layout.join_h_trailing_newline", %q{Lipgloss.join_horizontal(:top, "a\n", "b")}
  add "layout.join_h_non_string", %q{Lipgloss.join_horizontal(:top, "a", 1)}
  add "layout.join_h_nil", %q{Lipgloss.join_horizontal(:top, nil)}
  add "layout.join_h_bad_position", %q{Lipgloss.join_horizontal(:middle, "a")}
  add "layout.join_h_array_position", %q{Lipgloss.join_horizontal([], "a")}
  add "layout.join_h_array_arg", %q{Lipgloss.join_horizontal(:top, ["a", "b"])}
  add "layout.join_h_private", %q{Lipgloss._join_horizontal(0.5, ["a\nb", "c"])}
  add "layout.join_h_private_not_array", %q{Lipgloss._join_horizontal(0.5, "a")}
  add "layout.join_v_single", %q{Lipgloss.join_vertical(:left, "abc")}
  add "layout.join_v_none", %q{Lipgloss.join_vertical(:left)}
  add "layout.join_v_empty", %q{Lipgloss.join_vertical(:center, "", "abc", "")}
  add "layout.join_v_styled", %q{a = Lipgloss::Style.new.border(:normal).render("Top"); b = Lipgloss::Style.new.border(:thick).render("Bottom row"); Lipgloss.join_vertical(:center, a, b)}
  add "layout.join_v_ansi", %q{Lipgloss.join_vertical(:right, "\e[31mred\e[0m", "longer line")}
  add "layout.join_v_wide", %q{Lipgloss.join_vertical(:right, "日本語", "a")}
  add "layout.join_v_multiline_blocks", %q{Lipgloss.join_vertical(:center, "a\nbbb", "ccccc\nd")}
  add "layout.join_v_bad_position", %q{Lipgloss.join_vertical(Object.new, "a")}
  add "layout.join_v_non_string", %q{Lipgloss.join_vertical(:top, "a", :b)}
  add "layout.join_nested", %q{Lipgloss.join_vertical(:left, Lipgloss.join_horizontal(:top, "a", "b\nc"), "dddd")}

  # --- place ----------------------------------------------------------------------------------------
  %w[left center right].product(%w[top center bottom]).each do |h, v|
    add "layout.place_#{h}_#{v}", %{Lipgloss.place(7, 5, :#{h}, :#{v}, "ab\\nc")}
  end
  add "layout.place_float", %q{Lipgloss.place(10, 6, 0.25, 0.75, "x")}
  add "layout.place_smaller", %q{Lipgloss.place(2, 1, :center, :center, "hello\nworld")}
  add "layout.place_zero", %q{Lipgloss.place(0, 0, :center, :center, "hi")}
  add "layout.place_negative", %q{Lipgloss.place(-3, -3, :center, :center, "hi")}
  add "layout.place_empty", %q{Lipgloss.place(4, 2, :center, :center, "")}
  add "layout.place_wide", %q{Lipgloss.place(8, 3, :center, :center, "日本")}
  add "layout.place_styled", %q{Lipgloss.place(12, 5, :center, :center, Lipgloss::Style.new.border(:rounded).render("hi"))}
  add "layout.place_ansi", %q{Lipgloss.place(6, 3, :right, :bottom, "\e[31mab\e[0m")}
  add "layout.place_ws_chars", %q{Lipgloss.place(7, 3, :center, :center, "x", whitespace_chars: ".")}
  add "layout.place_ws_chars_multi", %q{Lipgloss.place(9, 3, :center, :center, "x", whitespace_chars: "ab")}
  add "layout.place_ws_chars_wide", %q{Lipgloss.place(9, 3, :center, :center, "x", whitespace_chars: "日")}
  add "layout.place_ws_fg", %q{Lipgloss.place(5, 3, :center, :center, "x", whitespace_chars: "-", whitespace_foreground: "#ff0000")}
  add "layout.place_ws_fg_ansi", %q{Lipgloss.place(5, 3, :center, :center, "x", whitespace_chars: "-", whitespace_foreground: "4")}
  add "layout.place_ws_fg_only", %q{Lipgloss.place(5, 3, :center, :center, "x", whitespace_foreground: "#ff0000")}
  add "layout.place_ws_fg_adaptive", %q{Lipgloss.place(5, 3, :center, :center, "x", whitespace_chars: "~", whitespace_foreground: Lipgloss::AdaptiveColor.new(light: "#ff0000", dark: "#00ff00"))}
  add "layout.place_ws_empty_opts", %q{Lipgloss.place(5, 3, :center, :center, "x", **{})}
  add "layout.place_ws_unknown_opt", %q{Lipgloss.place(5, 3, :center, :center, "x", foo: 1)}
  add "layout.place_ws_bad_chars", %q{Lipgloss.place(5, 3, :center, :center, "x", whitespace_chars: 1)}
  add "layout.place_ws_bad_fg", %q{Lipgloss.place(5, 3, :center, :center, "x", whitespace_foreground: 1)}
  add "layout.place_non_string", %q{Lipgloss.place(5, 3, :center, :center, 5)}
  add "layout.place_string_width", %q{Lipgloss.place("5", 3, :center, :center, "x")}
  add "layout.place_bad_position", %q{Lipgloss.place(5, 3, :middle, :center, "x")}
  add "layout.place_wrong_arity", %q{Lipgloss.place(5, 3, :center, "x")}
  add "layout.place_private", %q{Lipgloss._place(5, 3, 0.5, 0.5, "x")}

  %w[left center right].each do |h|
    add "layout.place_h_#{h}", %{Lipgloss.place_horizontal(8, :#{h}, "ab\\ncde")}
  end
  add "layout.place_h_float", %q{Lipgloss.place_horizontal(10, 0.3, "ab")}
  add "layout.place_h_smaller", %q{Lipgloss.place_horizontal(2, :center, "abcdef")}
  add "layout.place_h_wide", %q{Lipgloss.place_horizontal(7, :right, "日本")}
  add "layout.place_h_ansi", %q{Lipgloss.place_horizontal(7, :center, "\e[1mab\e[0m")}
  add "layout.place_h_empty", %q{Lipgloss.place_horizontal(3, :left, "")}
  add "layout.place_h_non_string", %q{Lipgloss.place_horizontal(3, :left, nil)}
  add "layout.place_h_bad_position", %q{Lipgloss.place_horizontal(3, "nowhere", "a")}
  %w[top center bottom].each do |v|
    add "layout.place_v_#{v}", %{Lipgloss.place_vertical(5, :#{v}, "ab\\nc")}
  end
  add "layout.place_v_float", %q{Lipgloss.place_vertical(6, 0.6, "x")}
  add "layout.place_v_smaller", %q{Lipgloss.place_vertical(1, :bottom, "a\nb\nc")}
  add "layout.place_v_empty", %q{Lipgloss.place_vertical(3, :top, "")}
  add "layout.place_v_non_string", %q{Lipgloss.place_vertical(3, :top, 1)}

  # --- width / height / size ------------------------------------------------------------------------
  {
    "ascii" => %q{"hello"}, "empty" => %q{""}, "multiline" => %q{"ab\ncdef\ng"}, "ansi" => %q{"\e[31mred\e[0m"},
    "ansi_256" => %q{"\e[38;5;196mx\e[0m"}, "osc_link" => %q{"\e]8;;http://x\alink\e]8;;\a"},
    "cjk" => %q{"日本語"}, "emoji" => %q{"😀"}, "emoji_zwj" => %q{"👨‍👩‍👧"}, "flag" => %q{"🇯🇵"},
    "skin_tone" => %q{"👍🏽"}, "combining" => %q{"é"}, "zero_width" => %q{"a​b"},
    "tab" => %q{"a\tb"}, "trailing_newline" => %q{"a\n"}, "only_newlines" => %q{"\n\n"},
    "crlf" => %q{"ab\r\ncd"}, "fullwidth" => %q{"ＡＢ"}, "box_drawing" => %q{"┌─┐"}, "mixed" => %q{"a日\n😀bc"},
    "styled" => %q{Lipgloss::Style.new.border(:normal).padding(1).render("hi")}, "control" => %q{"a\x01b"},
    "variation_selector" => %q{"☀️"}, "hangul" => %q{"한글"}
  }.each do |name, str|
    add "layout.width_#{name}", %{Lipgloss.width(#{str})}
    add "layout.height_#{name}", %{Lipgloss.height(#{str})}
    add "layout.size_#{name}", %{Lipgloss.size(#{str})}
  end
  add "layout.width_non_string", %q{Lipgloss.width(5)}
  add "layout.height_nil", %q{Lipgloss.height(nil)}
  add "layout.size_symbol", %q{Lipgloss.size(:a)}

  # --- Position helper --------------------------------------------------------------------------
  add "layout.position_constants", %q{[Lipgloss::TOP, Lipgloss::BOTTOM, Lipgloss::LEFT, Lipgloss::RIGHT, Lipgloss::CENTER]}
  add "layout.position_module_constants", %q{[Lipgloss::Position::TOP, Lipgloss::Position::BOTTOM, Lipgloss::Position::LEFT, Lipgloss::Position::RIGHT, Lipgloss::Position::CENTER]}
  add "layout.position_symbols", %q{Lipgloss::Position::SYMBOLS.transform_keys(&:to_s)}
  add "layout.position_resolve_symbol", %q{Lipgloss::Position.resolve(:right)}
  add "layout.position_resolve_string", %q{Lipgloss::Position.resolve("center")}
  add "layout.position_resolve_integer", %q{Lipgloss::Position.resolve(1)}
  add "layout.position_resolve_rational", %q{Lipgloss::Position.resolve(1r / 4)}
  add "layout.position_resolve_unknown", %q{Lipgloss::Position.resolve(:nope)}
  add "layout.position_resolve_unknown_string", %q{Lipgloss::Position.resolve("nope")}
  add "layout.position_resolve_nil", %q{Lipgloss::Position.resolve(nil)}
end
