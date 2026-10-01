# frozen_string_literal: true

LipglossCases.define("list") do
  enums = %w[bullet arabic alphabet roman dash asterisk]
  abc = %q{Lipgloss::List.new("Apple", "Banana", "Cherry")}

  add "list.basic", %{#{abc}.render}
  add "list.to_s", %{#{abc}.to_s}
  add "list.empty", %q{Lipgloss::List.new.render}
  add "list.single", %q{Lipgloss::List.new("one").render}
  add "list.items", %q{Lipgloss::List.new.items(["a", "b", "c"]).render}
  add "list.items_append", %q{Lipgloss::List.new("a").items(["b", "c"]).render}
  add "list.items_empty", %q{Lipgloss::List.new("a").items([]).render}
  add "list.item", %q{Lipgloss::List.new.item("a").item("b").render}
  add "list.item_after_new", %q{Lipgloss::List.new("a").item("b").render}
  add "list.immutable", %q{l = Lipgloss::List.new("a"); l.item("b"); l.render}
  add "list.multiline_items", %q{Lipgloss::List.new("line1\nline2", "single").render}
  add "list.wide_items", %q{Lipgloss::List.new("日本語", "😀 emoji", "한글").render}
  add "list.ansi_items", %q{Lipgloss::List.new("\e[31mred\e[0m", "plain").render}
  add "list.styled_items", %q{Lipgloss::List.new(Lipgloss::Style.new.bold(true).render("bold"), Lipgloss::Style.new.border(:normal).render("box")).render}
  add "list.empty_string_item", %q{Lipgloss::List.new("", "b").render}
  add "list.non_string_new", %q{Lipgloss::List.new("a", 1).render}
  add "list.non_string_item", %q{Lipgloss::List.new.item(1)}
  add "list.nil_item", %q{Lipgloss::List.new.item(nil)}
  add "list.items_not_array", %q{Lipgloss::List.new.items("a")}
  add "list.items_nested_array", %q{Lipgloss::List.new("x").items([["a"]]).render}
  add "list.items_with_list", %q{Lipgloss::List.new.items([Lipgloss::List.new("a")]).render}
  add "list.class_of_chain", %q{Lipgloss::List.new.item("a").class.name}

  # --- enumerators --------------------------------------------------------------------------------
  enums.each do |e|
    add "list.enum_#{e}", %{#{abc}.enumerator(:#{e}).render}
    add "list.enum_#{e}_many", %{Lipgloss::List.new.items((1..12).map { |i| "item \#{i}" }).enumerator(:#{e}).render}
    add "list.enum_#{e}_nested", %{Lipgloss::List.new("a", "b").item(Lipgloss::List.new("x", "y").enumerator(:#{e})).item("c").enumerator(:#{e}).render}
    add "list.enum_#{e}_multiline", %{Lipgloss::List.new("one\\ntwo", "three").enumerator(:#{e}).render}
  end
  add "list.enum_alphabet_27", %q{Lipgloss::List.new.items((1..28).map(&:to_s)).enumerator(:alphabet).render}
  add "list.enum_roman_large", %q{Lipgloss::List.new.items((1..40).map(&:to_s)).enumerator(:roman).render}
  add "list.enum_unknown", %{#{abc}.enumerator(:nope).render}
  add "list.enum_string", %{#{abc}.enumerator("roman").render}
  add "list.enum_nil", %{#{abc}.enumerator(nil).render}
  add "list.enum_override", %{#{abc}.enumerator(:roman).enumerator(:dash).render}

  # --- styles --------------------------------------------------------------------------------------
  add "list.enumerator_style", %{#{abc}.enumerator_style(Lipgloss::Style.new.foreground("#ff0000")).render}
  add "list.enumerator_style_padding", %{#{abc}.enumerator(:arabic).enumerator_style(Lipgloss::Style.new.padding_right(2)).render}
  add "list.enumerator_style_width", %{#{abc}.enumerator(:roman).enumerator_style(Lipgloss::Style.new.width(6).align(:right)).render}
  add "list.enumerator_style_bold", %{#{abc}.enumerator_style(Lipgloss::Style.new.bold(true)).render}
  add "list.item_style", %{#{abc}.item_style(Lipgloss::Style.new.foreground("#00ff00")).render}
  add "list.item_style_padding", %{#{abc}.item_style(Lipgloss::Style.new.padding_left(1)).render}
  add "list.item_style_bg", %{#{abc}.item_style(Lipgloss::Style.new.background("4").padding(0, 1)).render}
  add "list.item_style_border", %{#{abc}.item_style(Lipgloss::Style.new.border(:rounded)).render}
  add "list.item_style_width", %{#{abc}.item_style(Lipgloss::Style.new.width(10)).render}
  add "list.both_styles", %{#{abc}.enumerator(:arabic).enumerator_style(Lipgloss::Style.new.foreground("99").margin_right(1)).item_style(Lipgloss::Style.new.foreground("212")).render}
  add "list.styles_nested", %q{Lipgloss::List.new("a").item(Lipgloss::List.new("b", "c").item_style(Lipgloss::Style.new.italic(true))).item_style(Lipgloss::Style.new.bold(true)).render}
  add "list.enumerator_style_bad", %{#{abc}.enumerator_style("red")}
  add "list.item_style_bad", %{#{abc}.item_style(nil)}

  # --- nesting -------------------------------------------------------------------------------------
  add "list.nested", %q{Lipgloss::List.new("A", "B").item(Lipgloss::List.new("B1", "B2")).item("C").render}
  add "list.nested_first", %q{Lipgloss::List.new.item(Lipgloss::List.new("x", "y")).item("z").render}
  add "list.nested_deep", %q{Lipgloss::List.new("1").item(Lipgloss::List.new("1.1").item(Lipgloss::List.new("1.1.1", "1.1.2"))).item("2").render}
  add "list.nested_empty", %q{Lipgloss::List.new("a").item(Lipgloss::List.new).item("b").render}
  add "list.nested_only", %q{Lipgloss::List.new.item(Lipgloss::List.new("inner")).render}
  add "list.nested_mixed_enums", %q{Lipgloss::List.new("a", "b").enumerator(:roman).item(Lipgloss::List.new("c", "d").enumerator(:alphabet)).item("e").render}
  add "list.nested_styled_enum", %q{Lipgloss::List.new("a").item(Lipgloss::List.new("b").enumerator_style(Lipgloss::Style.new.foreground("1"))).render}
end
