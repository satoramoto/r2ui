# frozen_string_literal: true

LipglossCases.define("tree") do
  fruit = %q{Lipgloss::Tree.root("Fruit").child("Apple", "Banana", "Cherry")}

  add "tree.basic", %{#{fruit}.render}
  add "tree.to_s", %{#{fruit}.to_s}
  add "tree.empty", %q{Lipgloss::Tree.new.render}
  add "tree.new_with_root", %q{Lipgloss::Tree.new("Root").child("a").render}
  add "tree.new_root_only", %q{Lipgloss::Tree.new("Root").render}
  add "tree.root_only", %q{Lipgloss::Tree.root("Root").render}
  add "tree.no_root", %q{Lipgloss::Tree.new.child("a", "b").render}
  add "tree.no_root_nested", %q{Lipgloss::Tree.new.child("a", Lipgloss::Tree.root("b").child("c")).render}
  add "tree.set_root", %q{t = Lipgloss::Tree.new.child("a"); (t.root = "R"); t.render}
  add "tree.set_root_return", %q{Lipgloss::Tree.new.child("a").send(:root=, "R").render}
  add "tree.child_single", %q{Lipgloss::Tree.root("R").child("only").render}
  add "tree.child_chained", %q{Lipgloss::Tree.root("R").child("a").child("b").render}
  add "tree.children", %q{Lipgloss::Tree.root("R").children(["a", "b", "c"]).render}
  add "tree.children_empty", %q{Lipgloss::Tree.root("R").children([]).render}
  add "tree.children_then_child", %q{Lipgloss::Tree.root("R").children(["a"]).child("b").render}
  add "tree.children_non_string", %q{Lipgloss::Tree.root("R").children(["a", 1]).render}
  add "tree.children_not_array", %q{Lipgloss::Tree.root("R").children("a")}
  add "tree.child_none", %q{Lipgloss::Tree.root("R").child}
  add "tree.child_non_string", %q{Lipgloss::Tree.root("R").child(1)}
  add "tree.child_nil", %q{Lipgloss::Tree.root("R").child("a", nil)}
  add "tree.root_non_string", %q{Lipgloss::Tree.root(1)}
  add "tree.new_non_string", %q{Lipgloss::Tree.new(:r)}
  add "tree.new_two_args", %q{Lipgloss::Tree.new("a", "b").render}
  add "tree.immutable", %q{t = Lipgloss::Tree.root("R"); t.child("a"); t.render}
  add "tree.multiline_child", %q{Lipgloss::Tree.root("R").child("line1\nline2", "b").render}
  add "tree.multiline_root", %q{Lipgloss::Tree.root("R1\nR2").child("a").render}
  add "tree.wide_children", %q{Lipgloss::Tree.root("根").child("日本語", "😀", "한글").render}
  add "tree.ansi_children", %q{Lipgloss::Tree.root("R").child("\e[31mred\e[0m", "plain").render}
  add "tree.styled_child", %q{Lipgloss::Tree.root("R").child(Lipgloss::Style.new.border(:normal).render("box"), "after").render}
  add "tree.empty_child", %q{Lipgloss::Tree.root("R").child("", "b").render}
  add "tree.class_of_chain", %q{Lipgloss::Tree.root("R").child("a").class.name}

  # --- nesting -------------------------------------------------------------------------------------
  add "tree.nested", %q{Lipgloss::Tree.root(".").child("macOS", Lipgloss::Tree.root("Linux").child("NixOS", "Arch"), "BSD").render}
  add "tree.nested_deep", %q{Lipgloss::Tree.root("a").child(Lipgloss::Tree.root("b").child(Lipgloss::Tree.root("c").child("d", "e")), "f").render}
  add "tree.nested_last", %q{Lipgloss::Tree.root("a").child("b", Lipgloss::Tree.root("c").child("d")).render}
  add "tree.nested_no_root", %q{Lipgloss::Tree.root("a").child("b", Lipgloss::Tree.new.child("c", "d"), "e").render}
  add "tree.nested_empty", %q{Lipgloss::Tree.root("a").child(Lipgloss::Tree.new, "b").render}
  add "tree.nested_root_only", %q{Lipgloss::Tree.root("a").child(Lipgloss::Tree.root("b"), "c").render}
  add "tree.nested_multiline", %q{Lipgloss::Tree.root("a").child(Lipgloss::Tree.root("b\nb2").child("c\nc2")).render}

  # --- enumerators --------------------------------------------------------------------------------
  add "tree.enum_default", %{#{fruit}.enumerator(:default).render}
  add "tree.enum_rounded", %{#{fruit}.enumerator(:rounded).render}
  add "tree.enum_unknown", %{#{fruit}.enumerator(:nope).render}
  add "tree.enum_string", %{#{fruit}.enumerator("rounded").render}
  add "tree.enum_rounded_nested", %q{Lipgloss::Tree.root("a").child("b", Lipgloss::Tree.root("c").child("d", "e"), "f").enumerator(:rounded).render}
  add "tree.enum_nested_own", %q{Lipgloss::Tree.root("a").child("b", Lipgloss::Tree.root("c").child("d", "e").enumerator(:rounded), "f").render}
  add "tree.enum_rounded_multiline", %q{Lipgloss::Tree.root("R").child("x\ny", "z").enumerator(:rounded).render}

  # --- styles --------------------------------------------------------------------------------------
  add "tree.root_style", %{#{fruit}.root_style(Lipgloss::Style.new.bold(true).foreground("#ff0000")).render}
  add "tree.item_style", %{#{fruit}.item_style(Lipgloss::Style.new.foreground("#00ff00")).render}
  add "tree.enumerator_style", %{#{fruit}.enumerator_style(Lipgloss::Style.new.foreground("#0000ff")).render}
  add "tree.enumerator_style_padding", %{#{fruit}.enumerator_style(Lipgloss::Style.new.padding_right(1)).render}
  add "tree.item_style_padding", %{#{fruit}.item_style(Lipgloss::Style.new.padding_left(2)).render}
  add "tree.item_style_border", %{#{fruit}.item_style(Lipgloss::Style.new.border(:normal)).render}
  add "tree.root_style_border", %{#{fruit}.root_style(Lipgloss::Style.new.border(:rounded)).render}
  add "tree.all_styles", %{#{fruit}.root_style(Lipgloss::Style.new.bold(true)).item_style(Lipgloss::Style.new.italic(true)).enumerator_style(Lipgloss::Style.new.faint(true)).render}
  add "tree.styles_nested", %q{Lipgloss::Tree.root("a").child("b", Lipgloss::Tree.root("c").child("d")).item_style(Lipgloss::Style.new.foreground("1")).enumerator_style(Lipgloss::Style.new.foreground("2")).render}
  add "tree.styles_nested_own", %q{Lipgloss::Tree.root("a").child("b", Lipgloss::Tree.root("c").child("d").item_style(Lipgloss::Style.new.foreground("3"))).render}
  add "tree.style_bad", %{#{fruit}.item_style("red")}
  add "tree.root_style_bad", %{#{fruit}.root_style(nil)}

  # --- offset --------------------------------------------------------------------------------------
  five = %q{Lipgloss::Tree.root("R").child("a", "b", "c", "d", "e")}
  [[0, 0], [1, 0], [0, 1], [1, 1], [2, 2], [0, 5], [5, 0], [3, 3], [9, 9], [-1, 0], [0, -1], [-1, -1]].each do |s, e|
    add "tree.offset_#{s}_#{e}".tr("-", "m"), %{#{five}.offset(#{s}, #{e}).render}
  end
  add "tree.offset_nested", %q{Lipgloss::Tree.root("R").child("a", Lipgloss::Tree.root("b").child("c"), "d").offset(1, 1).render}
  add "tree.offset_string", %{#{five}.offset("1", 0)}
  add "tree.offset_one_arg", %{#{five}.offset(1)}
end
