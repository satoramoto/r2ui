# frozen_string_literal: true

LipglossCases.define("style") do
  attrs = %w[bold italic underline strikethrough reverse blink faint]

  # --- text attributes -------------------------------------------------------------------------------
  add "style.plain", %q{Lipgloss::Style.new.render("Hello")}
  add "style.plain_empty", %q{Lipgloss::Style.new.render("")}
  add "style.plain_multiline", %q{Lipgloss::Style.new.render("a\nbb\nccc")}
  attrs.each do |a|
    add "style.#{a}", %{Lipgloss::Style.new.#{a}(true).render("Hello")}
    add "style.#{a}_false", %{Lipgloss::Style.new.#{a}(false).render("Hello")}
    add "style.#{a}_words", %{Lipgloss::Style.new.#{a}(true).render("Hello World")}
    add "style.#{a}_multiline", %{Lipgloss::Style.new.#{a}(true).render("ab\\nc")}
    add "style.#{a}_getter_default", %{Lipgloss::Style.new.#{a}?}
    add "style.#{a}_getter_true", %{Lipgloss::Style.new.#{a}(true).#{a}?}
    add "style.#{a}_getter_false", %{Lipgloss::Style.new.#{a}(false).#{a}?}
    add "style.#{a}_unset", %{Lipgloss::Style.new.#{a}(true).unset_#{a}.render("Hello")}
    add "style.#{a}_unset_getter", %{Lipgloss::Style.new.#{a}(true).unset_#{a}.#{a}?}
    add "style.#{a}_truthy_string", %{Lipgloss::Style.new.#{a}("yes").#{a}?}
    add "style.#{a}_nil", %{Lipgloss::Style.new.#{a}(nil).#{a}?}
  end
  add "style.bold_italic", %q{Lipgloss::Style.new.bold(true).italic(true).render("Hi")}
  add "style.all_attrs", %q{Lipgloss::Style.new.bold(true).italic(true).underline(true).strikethrough(true).reverse(true).blink(true).faint(true).render("Hi")}
  add "style.bold_fg_bg", %q{Lipgloss::Style.new.bold(true).foreground("#ff0000").background("#0000ff").render("Hi")}
  add "style.underline_fg", %q{Lipgloss::Style.new.underline(true).foreground("5").render("a b")}
  add "style.chain_immutable", %q{s = Lipgloss::Style.new; s.bold(true); s.render("x")}
  add "style.chain_returns_new", %q{s = Lipgloss::Style.new; t = s.bold(true); [s.bold?, t.bold?]}
  add "style.class_of_chain", %q{Lipgloss::Style.new.bold(true).class.name}

  # --- getters ---------------------------------------------------------------------------------------
  add "style.get_foreground_default", %q{Lipgloss::Style.new.get_foreground}
  add "style.get_foreground_hex", %q{Lipgloss::Style.new.foreground("#FF00ff").get_foreground}
  add "style.get_foreground_ansi", %q{Lipgloss::Style.new.foreground("9").get_foreground}
  add "style.get_foreground_adaptive", %q{Lipgloss::Style.new.foreground(Lipgloss::AdaptiveColor.new(light: "#000", dark: "#fff")).get_foreground}
  add "style.get_foreground_complete", %q{Lipgloss::Style.new.foreground(Lipgloss::CompleteColor.new(true_color: "#ff0000", ansi256: 196, ansi: :red)).get_foreground}
  add "style.get_foreground_unset", %q{Lipgloss::Style.new.foreground("1").unset_foreground.get_foreground}
  add "style.get_foreground_empty", %q{Lipgloss::Style.new.foreground("").get_foreground}
  add "style.get_foreground_invalid", %q{Lipgloss::Style.new.foreground("nope").get_foreground}
  add "style.get_background_default", %q{Lipgloss::Style.new.get_background}
  add "style.get_background_hex", %q{Lipgloss::Style.new.background("#123456").get_background}
  add "style.get_background_adaptive", %q{Lipgloss::Style.new.background(Lipgloss::AdaptiveColor.new(light: "#000", dark: "#fff")).get_background}
  add "style.get_background_unset", %q{Lipgloss::Style.new.background("1").unset_background.get_background}
  add "style.get_width_default", %q{Lipgloss::Style.new.get_width}
  add "style.get_width", %q{Lipgloss::Style.new.width(12).get_width}
  add "style.get_width_unset", %q{Lipgloss::Style.new.width(12).unset_width.get_width}
  add "style.get_width_negative", %q{Lipgloss::Style.new.width(-4).get_width}
  add "style.get_height_default", %q{Lipgloss::Style.new.get_height}
  add "style.get_height", %q{Lipgloss::Style.new.height(3).get_height}
  add "style.get_height_unset", %q{Lipgloss::Style.new.height(3).unset_height.get_height}
  add "style.width_float_truncates", %q{Lipgloss::Style.new.width(7.9).get_width}

  # --- unset -----------------------------------------------------------------------------------------
  add "style.unset_foreground", %q{Lipgloss::Style.new.foreground("#ff0000").unset_foreground.render("x")}
  add "style.unset_background", %q{Lipgloss::Style.new.background("#ff0000").unset_background.render("x")}
  add "style.unset_width", %q{Lipgloss::Style.new.width(10).unset_width.render("x")}
  add "style.unset_height", %q{Lipgloss::Style.new.height(3).unset_height.render("x")}
  %w[top right bottom left].each do |side|
    add "style.unset_padding_#{side}", %{Lipgloss::Style.new.padding(1, 2).unset_padding_#{side}.render("x")}
    add "style.unset_margin_#{side}", %{Lipgloss::Style.new.margin(1, 2).unset_margin_#{side}.render("x")}
  end
  add "style.unset_border_style", %q{Lipgloss::Style.new.border(:rounded).unset_border_style.render("x")}
  add "style.unset_inline", %q{Lipgloss::Style.new.inline(true).unset_inline.render("a\nb")}
  add "style.unset_nothing_set", %q{Lipgloss::Style.new.unset_bold.unset_width.unset_padding_left.render("x")}

  # --- set_string / to_s -----------------------------------------------------------------------------
  add "style.to_s_empty", %q{Lipgloss::Style.new.to_s}
  add "style.to_s_bold_no_string", %q{Lipgloss::Style.new.bold(true).to_s}
  add "style.set_string_to_s", %q{Lipgloss::Style.new.set_string("Hello").to_s}
  add "style.set_string_bold_to_s", %q{Lipgloss::Style.new.set_string("Hello").bold(true).to_s}
  add "style.set_string_then_style", %q{Lipgloss::Style.new.bold(true).set_string("Hi").width(6).to_s}
  add "style.set_string_render_joins", %q{Lipgloss::Style.new.set_string("Hello").render("World")}
  add "style.set_string_render_empty", %q{Lipgloss::Style.new.set_string("Hello").render("")}
  add "style.set_string_twice", %q{Lipgloss::Style.new.set_string("a").set_string("b").to_s}
  add "style.set_string_multiline", %q{Lipgloss::Style.new.set_string("a\nb").border(:normal).to_s}
  add "style.to_s_interpolation", %q{"[#{Lipgloss::Style.new.set_string("x")}]"}
  add "style.set_string_non_string", %q{Lipgloss::Style.new.set_string(5)}
  add "style.render_non_string", %q{Lipgloss::Style.new.render(5)}
  add "style.render_nil", %q{Lipgloss::Style.new.render(nil)}
  add "style.render_symbol", %q{Lipgloss::Style.new.render(:hi)}
  add "style.render_no_args", %q{Lipgloss::Style.new.render}
  add "style.render_two_args", %q{Lipgloss::Style.new.render("a", "b")}
  add "style.new_with_args", %q{Lipgloss::Style.new(1)}

  # --- inherit ---------------------------------------------------------------------------------------
  add "style.inherit_bold", %q{Lipgloss::Style.new.inherit(Lipgloss::Style.new.bold(true)).render("x")}
  add "style.inherit_keeps_own", %q{Lipgloss::Style.new.bold(false).inherit(Lipgloss::Style.new.bold(true)).bold?}
  add "style.inherit_foreground", %q{Lipgloss::Style.new.inherit(Lipgloss::Style.new.foreground("#00ff00")).render("x")}
  add "style.inherit_foreground_not_override", %q{Lipgloss::Style.new.foreground("#ff0000").inherit(Lipgloss::Style.new.foreground("#00ff00")).render("x")}
  add "style.inherit_background", %q{Lipgloss::Style.new.inherit(Lipgloss::Style.new.background("4")).render("x")}
  add "style.inherit_padding_ignored", %q{Lipgloss::Style.new.inherit(Lipgloss::Style.new.padding(2)).render("x")}
  add "style.inherit_margin_ignored", %q{Lipgloss::Style.new.inherit(Lipgloss::Style.new.margin(2)).render("x")}
  add "style.inherit_width", %q{Lipgloss::Style.new.inherit(Lipgloss::Style.new.width(6)).render("x")}
  add "style.inherit_border", %q{Lipgloss::Style.new.inherit(Lipgloss::Style.new.border(:rounded)).render("x")}
  add "style.inherit_bg_to_margin", %q{Lipgloss::Style.new.margin(1).inherit(Lipgloss::Style.new.background("#ff0000")).render("x")}
  add "style.inherit_set_string", %q{Lipgloss::Style.new.inherit(Lipgloss::Style.new.set_string("parent")).to_s}
  add "style.inherit_align", %q{Lipgloss::Style.new.width(9).inherit(Lipgloss::Style.new.align(:right)).render("x")}
  add "style.inherit_multiple", %q{Lipgloss::Style.new.inherit(Lipgloss::Style.new.bold(true)).inherit(Lipgloss::Style.new.italic(true).bold(false)).render("x")}
  add "style.inherit_non_style", %q{Lipgloss::Style.new.inherit("bold")}
  add "style.inherit_getters", %q{s = Lipgloss::Style.new.inherit(Lipgloss::Style.new.italic(true).width(4)); [s.italic?, s.get_width]}

  # --- width / height / max --------------------------------------------------------------------------
  add "style.width_pad", %q{Lipgloss::Style.new.width(10).render("Hello")}
  add "style.width_exact", %q{Lipgloss::Style.new.width(5).render("Hello")}
  add "style.width_wraps_words", %q{Lipgloss::Style.new.width(10).render("The quick brown fox jumps over the lazy dog")}
  add "style.width_wraps_long_word", %q{Lipgloss::Style.new.width(4).render("abcdefghij")}
  add "style.width_zero", %q{Lipgloss::Style.new.width(0).render("Hello")}
  add "style.width_one", %q{Lipgloss::Style.new.width(1).render("Hello")}
  add "style.width_negative", %q{Lipgloss::Style.new.width(-3).render("Hello")}
  add "style.width_multiline", %q{Lipgloss::Style.new.width(6).render("a\nbbb\ncc")}
  add "style.width_with_bg", %q{Lipgloss::Style.new.width(8).background("#333333").render("Hi")}
  add "style.width_string_arg", %q{Lipgloss::Style.new.width("10")}
  add "style.width_nil_arg", %q{Lipgloss::Style.new.width(nil)}
  add "style.height_pad", %q{Lipgloss::Style.new.height(3).render("Hello")}
  add "style.height_less_than_content", %q{Lipgloss::Style.new.height(1).render("a\nb\nc")}
  add "style.height_zero", %q{Lipgloss::Style.new.height(0).render("a\nb")}
  add "style.width_height", %q{Lipgloss::Style.new.width(6).height(3).render("Hi")}
  add "style.width_height_bg", %q{Lipgloss::Style.new.width(6).height(3).background("2").render("Hi")}
  add "style.max_width_truncates", %q{Lipgloss::Style.new.max_width(3).render("Hello")}
  add "style.max_width_larger", %q{Lipgloss::Style.new.max_width(30).render("Hello")}
  add "style.max_width_multiline", %q{Lipgloss::Style.new.max_width(2).render("abc\ndefg\nh")}
  add "style.max_width_zero", %q{Lipgloss::Style.new.max_width(0).render("Hello")}
  add "style.max_width_with_border", %q{Lipgloss::Style.new.border(:normal).max_width(4).render("Hello")}
  add "style.max_width_ansi_content", %q{Lipgloss::Style.new.max_width(3).render("\e[31mHello\e[0m")}
  add "style.max_width_wide", %q{Lipgloss::Style.new.max_width(3).render("日本語")}
  add "style.max_height_truncates", %q{Lipgloss::Style.new.max_height(2).render("a\nb\nc\nd")}
  add "style.max_height_larger", %q{Lipgloss::Style.new.max_height(9).render("a\nb")}
  add "style.max_height_zero", %q{Lipgloss::Style.new.max_height(0).render("a\nb")}
  add "style.max_height_with_border", %q{Lipgloss::Style.new.border(:normal).max_height(3).render("a\nb\nc")}
  add "style.width_and_max_width", %q{Lipgloss::Style.new.width(10).max_width(5).render("Hello World")}

  # --- align ----------------------------------------------------------------------------------------
  {
    "left" => ":left", "center" => ":center", "right" => ":right", "float_quarter" => "0.25",
    "integer_one" => "1", "string_center" => %q{"center"}, "constant_right" => "Lipgloss::RIGHT"
  }.each do |name, pos|
    add "style.align_#{name}", %{Lipgloss::Style.new.width(10).align(#{pos}).render("Hi")}
    add "style.align_#{name}_multiline", %{Lipgloss::Style.new.align(#{pos}).render("a\\nbbbb\\ncc")}
  end
  add "style.align_center_odd", %q{Lipgloss::Style.new.width(6).align(:center).render("abc")}
  add "style.align_two_positions", %q{Lipgloss::Style.new.width(7).height(5).align(:center, :bottom).render("x")}
  add "style.align_two_top", %q{Lipgloss::Style.new.width(7).height(3).align(:right, :top).render("x")}
  add "style.align_vertical_center", %q{Lipgloss::Style.new.height(5).align_vertical(:center).render("x")}
  add "style.align_vertical_bottom", %q{Lipgloss::Style.new.height(4).align_vertical(:bottom).render("a\nb")}
  add "style.align_vertical_float", %q{Lipgloss::Style.new.height(5).align_vertical(0.75).render("x")}
  add "style.align_horizontal_right", %q{Lipgloss::Style.new.width(5).align_horizontal(:right).render("x")}
  add "style.align_horizontal_center_multi", %q{Lipgloss::Style.new.align_horizontal(:center).render("a\nabcde")}
  add "style.align_bg", %q{Lipgloss::Style.new.width(8).align(:center).background("#00ff00").render("ab")}
  add "style.align_out_of_range", %q{Lipgloss::Style.new.width(8).align(2.5).render("ab")}
  add "style.align_negative", %q{Lipgloss::Style.new.width(8).align(-1).render("ab")}
  add "style.align_unknown_symbol", %q{Lipgloss::Style.new.align(:middle)}
  add "style.align_unknown_string", %q{Lipgloss::Style.new.align("middle")}
  add "style.align_nil", %q{Lipgloss::Style.new.align(nil)}
  add "style.align_none", %q{Lipgloss::Style.new.align}
  add "style.align_three", %q{Lipgloss::Style.new.align(:left, :top, :left)}
  add "style.align_horizontal_bad", %q{Lipgloss::Style.new.align_horizontal([])}
  add "style.private_align_string", %q{Lipgloss::Style.new._align("left")}

  # --- padding ---------------------------------------------------------------------------------------
  add "style.padding_1", %q{Lipgloss::Style.new.padding(1).render("x")}
  add "style.padding_2", %q{Lipgloss::Style.new.padding(1, 2).render("x")}
  add "style.padding_3", %q{Lipgloss::Style.new.padding(1, 2, 3).render("x")}
  add "style.padding_4", %q{Lipgloss::Style.new.padding(1, 2, 3, 4).render("x")}
  add "style.padding_zero", %q{Lipgloss::Style.new.padding(0).render("x")}
  add "style.padding_negative", %q{Lipgloss::Style.new.padding(-1).render("x")}
  add "style.padding_5", %q{Lipgloss::Style.new.padding(1, 2, 3, 4, 5)}
  add "style.padding_none", %q{Lipgloss::Style.new.padding}
  add "style.padding_string", %q{Lipgloss::Style.new.padding("1")}
  %w[top right bottom left].each_with_index do |side, i|
    add "style.padding_#{side}", %{Lipgloss::Style.new.padding_#{side}(#{i + 1}).render("x")}
    add "style.padding_#{side}_bg", %{Lipgloss::Style.new.padding_#{side}(2).background("#ff0000").render("ab\\nc")}
  end
  add "style.padding_bg", %q{Lipgloss::Style.new.padding(1, 2).background("#0000ff").render("Hi")}
  add "style.padding_fg_only", %q{Lipgloss::Style.new.padding(0, 1).foreground("#0000ff").render("Hi")}
  add "style.padding_multiline", %q{Lipgloss::Style.new.padding(0, 1).render("a\nbbb")}
  add "style.padding_with_width", %q{Lipgloss::Style.new.padding(0, 2).width(10).render("Hello world again")}
  add "style.padding_underline", %q{Lipgloss::Style.new.padding(0, 2).underline(true).render("ab")}
  add "style.padding_reverse", %q{Lipgloss::Style.new.padding(0, 1).reverse(true).render("ab")}

  # --- margin ----------------------------------------------------------------------------------------
  add "style.margin_1", %q{Lipgloss::Style.new.margin(1).render("x")}
  add "style.margin_2", %q{Lipgloss::Style.new.margin(1, 2).render("x")}
  add "style.margin_3", %q{Lipgloss::Style.new.margin(1, 2, 3).render("x")}
  add "style.margin_4", %q{Lipgloss::Style.new.margin(1, 2, 3, 4).render("x")}
  add "style.margin_zero", %q{Lipgloss::Style.new.margin(0).render("x")}
  add "style.margin_negative", %q{Lipgloss::Style.new.margin(-2).render("x")}
  add "style.margin_5", %q{Lipgloss::Style.new.margin(1, 1, 1, 1, 1)}
  add "style.margin_none", %q{Lipgloss::Style.new.margin}
  add "style.margin_float", %q{Lipgloss::Style.new.margin(1.9).render("x")}
  %w[top right bottom left].each_with_index do |side, i|
    add "style.margin_#{side}", %{Lipgloss::Style.new.margin_#{side}(#{i + 1}).render("x")}
    add "style.margin_#{side}_bg", %{Lipgloss::Style.new.margin_#{side}(1).margin_background("#ff0000").render("ab\\nc")}
  end
  add "style.margin_background", %q{Lipgloss::Style.new.margin(1, 2).margin_background("#00ff00").render("Hi")}
  add "style.margin_background_ansi", %q{Lipgloss::Style.new.margin(1).margin_background("3").render("Hi")}
  add "style.margin_background_no_margin", %q{Lipgloss::Style.new.margin_background("#00ff00").render("Hi")}
  add "style.margin_background_from_bg", %q{Lipgloss::Style.new.margin(1).background("#00ff00").render("Hi")}
  add "style.margin_background_and_bg", %q{Lipgloss::Style.new.margin(1).background("#00ff00").margin_background("#ff0000").render("Hi")}
  add "style.margin_background_invalid_type", %q{Lipgloss::Style.new.margin_background(Lipgloss::AdaptiveColor.new(light: "#000", dark: "#fff"))}
  add "style.margin_padding_border", %q{Lipgloss::Style.new.margin(1).padding(1).border(:normal).render("x")}
  add "style.margin_multiline", %q{Lipgloss::Style.new.margin(0, 2).render("a\nbbb")}

  # --- inline ----------------------------------------------------------------------------------------
  add "style.inline_newlines", %q{Lipgloss::Style.new.inline(true).render("a\nb\nc")}
  add "style.inline_ignores_padding", %q{Lipgloss::Style.new.inline(true).padding(1).render("x")}
  add "style.inline_ignores_margin", %q{Lipgloss::Style.new.inline(true).margin(1).render("x")}
  add "style.inline_ignores_border", %q{Lipgloss::Style.new.inline(true).border(:normal).render("x")}
  add "style.inline_with_width", %q{Lipgloss::Style.new.inline(true).width(3).render("hello world")}
  add "style.inline_max_width", %q{Lipgloss::Style.new.inline(true).max_width(3).render("hello\nworld")}
  add "style.inline_bold", %q{Lipgloss::Style.new.inline(true).bold(true).render("a\nb")}
  add "style.inline_false", %q{Lipgloss::Style.new.inline(false).padding(0, 1).render("a\nb")}

  # --- tab width -------------------------------------------------------------------------------------
  add "style.tab_default", %q{Lipgloss::Style.new.render("a\tb")}
  add "style.tab_width_2", %q{Lipgloss::Style.new.tab_width(2).render("a\tb")}
  add "style.tab_width_0", %q{Lipgloss::Style.new.tab_width(0).render("a\tb")}
  add "style.tab_width_keep", %q{Lipgloss::Style.new.tab_width(Lipgloss::NO_TAB_CONVERSION).render("a\tb")}
  add "style.tab_width_8_multi", %q{Lipgloss::Style.new.tab_width(8).render("\ta\n\t\tb")}
  add "style.tab_width_with_width", %q{Lipgloss::Style.new.tab_width(4).width(10).render("x\ty")}

  # --- underline / strikethrough spaces -------------------------------------------------------------
  add "style.underline_spaces_true", %q{Lipgloss::Style.new.underline(true).underline_spaces(true).render("a b")}
  add "style.underline_spaces_false", %q{Lipgloss::Style.new.underline(true).underline_spaces(false).render("a b")}
  add "style.underline_spaces_alone", %q{Lipgloss::Style.new.underline_spaces(true).render("a b")}
  add "style.strikethrough_spaces_true", %q{Lipgloss::Style.new.strikethrough(true).strikethrough_spaces(true).render("a b")}
  add "style.strikethrough_spaces_false", %q{Lipgloss::Style.new.strikethrough(true).strikethrough_spaces(false).render("a b")}
  add "style.strikethrough_spaces_alone", %q{Lipgloss::Style.new.strikethrough_spaces(true).render("a  b")}
  add "style.underline_padding_spaces", %q{Lipgloss::Style.new.underline(true).width(6).render("ab")}

  # --- wrapping and wide / special input --------------------------------------------------------------
  add "style.wrap_cjk", %q{Lipgloss::Style.new.width(5).render("日本語のテキスト")}
  add "style.wrap_cjk_mixed", %q{Lipgloss::Style.new.width(6).render("ab日本cd語ef")}
  add "style.wrap_emoji", %q{Lipgloss::Style.new.width(4).render("😀😃😄😁😆")}
  add "style.wrap_emoji_zwj", %q{Lipgloss::Style.new.width(3).render("👨‍👩‍👧 👍🏽 x")}
  add "style.wrap_ansi_input", %q{Lipgloss::Style.new.width(5).render("\e[31mred text here\e[0m")}
  add "style.wrap_ansi_styled", %q{Lipgloss::Style.new.bold(true).width(4).render("\e[32mgreen\e[0m and")}
  add "style.wrap_trailing_spaces", %q{Lipgloss::Style.new.width(5).render("ab   ")}
  add "style.wrap_leading_spaces", %q{Lipgloss::Style.new.width(5).render("   ab cd ef")}
  add "style.wrap_hyphen", %q{Lipgloss::Style.new.width(6).render("well-known long-word")}
  add "style.wrap_newlines", %q{Lipgloss::Style.new.width(4).render("ab\n\ncd ef gh")}
  add "style.wrap_crlf", %q{Lipgloss::Style.new.width(10).render("a\r\nb")}
  add "style.combining_marks", %q{Lipgloss::Style.new.width(4).render("éé")}
  add "style.ansi_passthrough", %q{Lipgloss::Style.new.render("\e[1mbold\e[0m")}
  add "style.ansi_with_fg", %q{Lipgloss::Style.new.foreground("#ff0000").render("a\e[0mb")}
  add "style.fg_multiline", %q{Lipgloss::Style.new.foreground("#ff0000").render("ab\ncd")}
  add "style.bg_multiline_uneven", %q{Lipgloss::Style.new.background("#ff0000").render("a\nbcd")}
  add "style.wide_with_border", %q{Lipgloss::Style.new.border(:normal).render("日本")}
  add "style.emoji_with_padding", %q{Lipgloss::Style.new.padding(0, 1).background("1").render("🎉")}
  add "style.unicode_width_center", %q{Lipgloss::Style.new.width(8).align(:center).render("日本")}
  add "style.empty_with_width", %q{Lipgloss::Style.new.width(3).render("")}
  add "style.empty_with_border", %q{Lipgloss::Style.new.border(:normal).render("")}
  add "style.empty_with_padding", %q{Lipgloss::Style.new.padding(1).render("")}
  add "style.newline_only", %q{Lipgloss::Style.new.border(:normal).render("\n")}
  add "style.trailing_newline", %q{Lipgloss::Style.new.render("a\n")}

  # --- full compositions -----------------------------------------------------------------------------
  add "style.card", %q{Lipgloss::Style.new.bold(true).foreground("#FAFAFA").background("#7D56F4").padding(1, 4).width(22).render("Hello, kitty")}
  add "style.card_border", %q{Lipgloss::Style.new.border(:rounded).border_foreground("#874BFD").padding(1, 2).margin(1).width(20).align(:center).render("Dialog\nbox")}
  add "style.reuse_style", %q{s = Lipgloss::Style.new.foreground("2").padding(0, 1); [s.render("a"), s.render("bb")]}
end
