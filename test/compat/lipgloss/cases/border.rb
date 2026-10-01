# frozen_string_literal: true

LipglossCases.define("border") do
  types = %w[normal rounded thick double hidden block outer_half_block inner_half_block ascii]

  types.each do |t|
    add "border.#{t}", %{Lipgloss::Style.new.border(:#{t}).render("Hello")}
    add "border.#{t}_multiline", %{Lipgloss::Style.new.border(:#{t}).render("ab\\ncdef\\ng")}
    add "border.#{t}_padding", %{Lipgloss::Style.new.border(:#{t}).padding(1, 2).render("x")}
    add "border.#{t}_fg", %{Lipgloss::Style.new.border(:#{t}).border_foreground("#ff8800").render("x")}
    add "border.#{t}_style_only", %{Lipgloss::Style.new.border_style(:#{t}).render("x")}
  end
  add "border.markdown_style", %q{Lipgloss::Style.new.border(:markdown).render("x")}
  add "border.unknown_symbol", %q{Lipgloss::Style.new.border(:nope).render("x")}
  add "border.string_type", %q{Lipgloss::Style.new.border("rounded").render("x")}
  add "border.nil_type", %q{Lipgloss::Style.new.border(nil).render("x")}
  add "border.constant", %q{Lipgloss::Style.new.border(Lipgloss::DOUBLE_BORDER).render("x")}
  add "border.module_constant", %q{Lipgloss::Style.new.border(Lipgloss::Border::OUTER_HALF_BLOCK).render("x")}
  add "border.no_args", %q{Lipgloss::Style.new.border}
  add "border.constants", %q{[Lipgloss::Border::NORMAL, Lipgloss::Border::ROUNDED, Lipgloss::Border::THICK, Lipgloss::Border::DOUBLE, Lipgloss::Border::ASCII, Lipgloss::Border::HIDDEN, Lipgloss::Border::BLOCK, Lipgloss::Border::OUTER_HALF_BLOCK, Lipgloss::Border::INNER_HALF_BLOCK].map(&:to_s)}
  add "border.top_constants", %q{[Lipgloss::NORMAL_BORDER, Lipgloss::ROUNDED_BORDER, Lipgloss::THICK_BORDER, Lipgloss::DOUBLE_BORDER, Lipgloss::HIDDEN_BORDER, Lipgloss::BLOCK_BORDER, Lipgloss::ASCII_BORDER].map(&:to_s)}

  # --- per-side toggles via border(type, *sides) --------------------------------------------------------
  [
    %w[true], %w[false], %w[true false], %w[false true], %w[true false true], %w[true true false true],
    %w[false false false false], %w[true false false false], %w[false true false false],
    %w[false false true false], %w[false false false true], %w[true true true true true]
  ].each do |sides|
    add "border.sides_#{sides.map { |s| s[0] }.join}", %{Lipgloss::Style.new.border(:normal, #{sides.join(", ")}).render("ab\\ncd")}
  end
  add "border.sides_truthy", %q{Lipgloss::Style.new.border(:rounded, 1, nil).render("x")}

  # --- per-side toggles via border_<side> ------------------------------------------------------------
  %w[top right bottom left].each do |side|
    add "border.only_#{side}", %{Lipgloss::Style.new.border_style(:normal).border_#{side}(true).render("ab")}
    add "border.without_#{side}", %{Lipgloss::Style.new.border(:normal).border_#{side}(false).render("ab")}
    add "border.#{side}_no_style", %{Lipgloss::Style.new.border_#{side}(true).render("ab")}
  end
  add "border.top_bottom", %q{Lipgloss::Style.new.border_style(:double).border_top(true).border_bottom(true).render("ab")}
  add "border.left_right", %q{Lipgloss::Style.new.border_style(:thick).border_left(true).border_right(true).render("ab\nc")}
  add "border.unset_style_keeps_sides", %q{Lipgloss::Style.new.border(:rounded).unset_border_style.border_top(true).render("ab")}

  # --- colors --------------------------------------------------------------------------------------
  add "border.fg", %q{Lipgloss::Style.new.border(:normal).border_foreground("#00ff00").render("x")}
  add "border.bg", %q{Lipgloss::Style.new.border(:normal).border_background("#0000ff").render("x")}
  add "border.fg_bg", %q{Lipgloss::Style.new.border(:rounded).border_foreground("1").border_background("4").render("x")}
  add "border.fg_ansi256", %q{Lipgloss::Style.new.border(:normal).border_foreground("201").render("x")}
  add "border.fg_adaptive", %q{Lipgloss::Style.new.border(:normal).border_foreground(Lipgloss::AdaptiveColor.new(light: "#ff0000", dark: "#00ff00")).render("x")}
  add "border.bg_adaptive", %q{Lipgloss::Style.new.border(:normal).border_background(Lipgloss::AdaptiveColor.new(light: "#ff0000", dark: "#00ff00")).render("x")}
  add "border.fg_complete", %q{Lipgloss::Style.new.border(:normal).border_foreground(Lipgloss::CompleteColor.new(true_color: "#ff0000", ansi256: 9, ansi: 1))}
  add "border.fg_symbol", %q{Lipgloss::Style.new.border(:normal).border_foreground(:red)}
  add "border.fg_integer", %q{Lipgloss::Style.new.border(:normal).border_foreground(5)}
  add "border.fg_without_border", %q{Lipgloss::Style.new.border_foreground("#00ff00").render("x")}
  add "border.fg_with_text_colors", %q{Lipgloss::Style.new.border(:normal).border_foreground("#00ff00").foreground("#ff0000").background("#0000ff").render("x")}
  %w[top right bottom left].each_with_index do |side, i|
    add "border.#{side}_fg", %{Lipgloss::Style.new.border(:normal).border_#{side}_foreground("#{i + 1}").render("ab\\nc")}
    add "border.#{side}_bg", %{Lipgloss::Style.new.border(:normal).border_#{side}_background("#{i + 9}").render("ab\\nc")}
    add "border.#{side}_fg_hex", %{Lipgloss::Style.new.border(:double).border_#{side}_foreground("#a0b0c0").render("x")}
    add "border.#{side}_fg_bad_type", %{Lipgloss::Style.new.border_#{side}_foreground(Lipgloss::AdaptiveColor.new(light: "1", dark: "2"))}
    add "border.#{side}_bg_bad_type", %{Lipgloss::Style.new.border_#{side}_background(3)}
  end
  add "border.all_side_colors", %q{Lipgloss::Style.new.border(:rounded).border_top_foreground("1").border_right_foreground("2").border_bottom_foreground("3").border_left_foreground("4").render("ab")}
  add "border.side_overrides_all", %q{Lipgloss::Style.new.border(:normal).border_foreground("1").border_left_foreground("2").render("ab")}
  add "border.fg_then_side", %q{Lipgloss::Style.new.border(:normal).border_top_foreground("2").border_foreground("1").render("ab")}

  # --- border_custom ---------------------------------------------------------------------------------
  add "border.custom_full", %q{Lipgloss::Style.new.border_custom(top: "-", bottom: "=", left: "[", right: "]", top_left: "1", top_right: "2", bottom_left: "3", bottom_right: "4").render("ab\ncd")}
  add "border.custom_sides_only", %q{Lipgloss::Style.new.border_custom(left: "|", right: "|").render("ab")}
  add "border.custom_top_only", %q{Lipgloss::Style.new.border_custom(top: "~").render("ab")}
  add "border.custom_corners_only", %q{Lipgloss::Style.new.border_custom(top_left: "+", top_right: "+", bottom_left: "+", bottom_right: "+").render("ab")}
  add "border.custom_multichar_top", %q{Lipgloss::Style.new.border_custom(top: "-=", bottom: "*", left: "|", right: "|", top_left: "+", top_right: "+", bottom_left: "+", bottom_right: "+").render("abcde")}
  add "border.custom_wide_chars", %q{Lipgloss::Style.new.border_custom(top: "═", bottom: "═", left: "║", right: "║", top_left: "╔", top_right: "╗", bottom_left: "╚", bottom_right: "╝").render("x")}
  add "border.custom_emoji", %q{Lipgloss::Style.new.border_custom(top: "🌟", bottom: "🌟", left: "🌟", right: "🌟", top_left: "🌟", top_right: "🌟", bottom_left: "🌟", bottom_right: "🌟").render("abcd")}
  add "border.custom_with_fg", %q{Lipgloss::Style.new.border_custom(top: "-", bottom: "-", left: "|", right: "|", top_left: "+", top_right: "+", bottom_left: "+", bottom_right: "+").border_foreground("#ff0000").render("x")}
  add "border.custom_middles", %q{Lipgloss::Style.new.border_custom(top: "-", middle: "+", middle_left: "<", middle_right: ">", middle_top: "v", middle_bottom: "^").render("x")}
  add "border.custom_no_kwargs", %q{Lipgloss::Style.new.border_custom}
  add "border.custom_positional", %q{Lipgloss::Style.new.border_custom({top: "-"})}
  add "border.custom_unknown_key", %q{Lipgloss::Style.new.border_custom(foo: "x", top: "-").render("ab")}
  add "border.custom_non_string", %q{Lipgloss::Style.new.border_custom(top: 1)}
  add "border.custom_then_side_off", %q{Lipgloss::Style.new.border_custom(top: "-", bottom: "-", left: "|", right: "|", top_left: "+", top_right: "+", bottom_left: "+", bottom_right: "+").border_left(false).render("x")}

  # --- borders with layout ---------------------------------------------------------------------------
  add "border.with_width", %q{Lipgloss::Style.new.border(:normal).width(10).render("Hi")}
  add "border.with_width_wrap", %q{Lipgloss::Style.new.border(:rounded).width(8).render("Hello there world")}
  add "border.with_height", %q{Lipgloss::Style.new.border(:normal).height(3).render("Hi")}
  add "border.with_align_center", %q{Lipgloss::Style.new.border(:normal).width(10).align(:center).render("Hi")}
  add "border.with_align_right_multi", %q{Lipgloss::Style.new.border(:thick).align(:right).render("a\nbbb")}
  add "border.with_margin", %q{Lipgloss::Style.new.border(:normal).margin(1, 2).render("Hi")}
  add "border.with_margin_bg", %q{Lipgloss::Style.new.border(:normal).margin(1).margin_background("#ff0000").render("Hi")}
  add "border.with_padding_bg", %q{Lipgloss::Style.new.border(:normal).padding(1).background("#330033").render("Hi")}
  add "border.with_bg_only", %q{Lipgloss::Style.new.border(:normal).background("#330033").render("Hi")}
  add "border.with_bold_text", %q{Lipgloss::Style.new.border(:normal).bold(true).render("Hi")}
  add "border.with_max_width", %q{Lipgloss::Style.new.border(:normal).max_width(5).render("Hello")}
  add "border.with_width_and_padding", %q{Lipgloss::Style.new.border(:double).width(12).padding(0, 1).render("wrap these words")}
  add "border.hidden_with_bg", %q{Lipgloss::Style.new.border(:hidden).border_background("#ff0000").render("x")}
  add "border.ansi_content", %q{Lipgloss::Style.new.border(:normal).render("\e[31mred\e[0m\nplain")}
  add "border.inline_ignored", %q{Lipgloss::Style.new.border(:normal).inline(true).render("a\nb")}
  add "border.nested", %q{inner = Lipgloss::Style.new.border(:normal).render("in"); Lipgloss::Style.new.border(:double).padding(0, 1).render(inner)}
end
