# frozen_string_literal: true

LipglossCases.define("misc") do
  add "misc.version", %q{Lipgloss.version}
  add "misc.upstream_version", %q{Lipgloss.upstream_version}
  add "misc.gem_version_constant", %q{Lipgloss::VERSION}
  add "misc.has_dark_background", %q{Lipgloss.has_dark_background?}
  add "misc.adaptive_probe", %q{Lipgloss::Style.new.foreground(Lipgloss::AdaptiveColor.new(light: "#000000", dark: "#ffffff")).render("x")}
  add "misc.no_tab_conversion", %q{Lipgloss::NO_TAB_CONVERSION}
  add "misc.constants_sorted", %q{Lipgloss.constants.map(&:to_s).sort}
  add "misc.style_class", %q{Lipgloss::Style.name}
  add "misc.classes", %q{[Lipgloss::Style, Lipgloss::Table, Lipgloss::List, Lipgloss::Tree, Lipgloss::AdaptiveColor, Lipgloss::CompleteColor, Lipgloss::CompleteAdaptiveColor].map { |k| [k.name, k.superclass.name] }}
  add "misc.modules", %q{[Lipgloss, Lipgloss::Position, Lipgloss::Border, Lipgloss::ANSIColor, Lipgloss::ColorBlend].map { |m| [m.name, m.class.name] }}
  add "misc.color_blend_constants", %q{Lipgloss::ColorBlend.constants.map(&:to_s).sort}
  add "misc.border_constants", %q{Lipgloss::Border.constants.map(&:to_s).sort}
  add "misc.position_constants", %q{Lipgloss::Position.constants.map(&:to_s).sort}
  add "misc.table_constants", %q{Lipgloss::Table.constants.map(&:to_s).sort}

  # Public method surface (names only, sorted) so a missing or extra method shows up.
  add "misc.style_methods", %q{(Lipgloss::Style.public_instance_methods(false)).map(&:to_s).sort}
  add "misc.table_methods", %q{(Lipgloss::Table.public_instance_methods(false)).map(&:to_s).sort}
  add "misc.list_methods", %q{(Lipgloss::List.public_instance_methods(false)).map(&:to_s).sort}
  add "misc.tree_methods", %q{(Lipgloss::Tree.public_instance_methods(false)).map(&:to_s).sort}
  add "misc.lipgloss_singleton_methods", %q{Lipgloss.singleton_methods(false).map(&:to_s).sort}
  add "misc.color_blend_singleton_methods", %q{Lipgloss::ColorBlend.singleton_methods(false).map(&:to_s).sort}
  add "misc.tree_singleton_methods", %q{Lipgloss::Tree.singleton_methods(false).map(&:to_s).sort}
  add "misc.adaptive_methods", %q{Lipgloss::AdaptiveColor.public_instance_methods(false).map(&:to_s).sort}
  add "misc.complete_methods", %q{Lipgloss::CompleteColor.public_instance_methods(false).map(&:to_s).sort}

  # Arity of the public API.
  add "misc.style_arities", %q{%i[render bold foreground width padding margin border border_custom align align_horizontal set_string inherit to_s bold? get_width unset_bold].map { |m| [m.to_s, Lipgloss::Style.instance_method(m).arity] }}
  add "misc.module_arities", %q{%i[join_horizontal join_vertical place place_horizontal place_vertical width height size has_dark_background? version upstream_version].map { |m| [m.to_s, Lipgloss.method(m).arity] }}
  add "misc.table_arities", %q{%i[headers row rows border border_style width height offset wrap clear_rows render style_func].map { |m| [m.to_s, Lipgloss::Table.instance_method(m).arity] }}
  add "misc.list_tree_arities", %q{[Lipgloss::List.instance_method(:initialize).arity, Lipgloss::List.instance_method(:item).arity, Lipgloss::Tree.instance_method(:initialize).arity, Lipgloss::Tree.instance_method(:child).arity, Lipgloss::Tree.instance_method(:offset).arity]}

  # Errors for bad arguments.
  add "misc.err_bold_arity", %q{Lipgloss::Style.new.bold}
  add "misc.err_bold_arity_two", %q{Lipgloss::Style.new.bold(true, false)}
  add "misc.err_width_arity", %q{Lipgloss.width}
  add "misc.err_join_no_position", %q{Lipgloss.join_horizontal}
  add "misc.err_unknown_method", %q{Lipgloss::Style.new.colour("red")}
  add "misc.err_list_new_kwargs", %q{Lipgloss::List.new(a: 1).render}
  add "misc.err_padding_float", %q{Lipgloss::Style.new.padding(1.5).render("x")}
  add "misc.err_padding_nil", %q{Lipgloss::Style.new.padding(nil)}
  add "misc.err_width_huge", %q{Lipgloss::Style.new.width(2**40)}
  add "misc.err_dup", %q{Lipgloss::Style.new.bold(true).dup.render("x")}
  add "misc.err_clone", %q{Lipgloss::Style.new.bold(true).clone.bold?}
  add "misc.style_equal", %q{Lipgloss::Style.new == Lipgloss::Style.new}
  add "misc.frozen_string_input", %q{Lipgloss::Style.new.bold(true).render("x".freeze)}
  add "misc.binary_string_input", %q{Lipgloss::Style.new.render("abc".b)}
  add "misc.result_encoding", %q{Lipgloss::Style.new.render("abc".b).encoding.name}
  add "misc.result_frozen", %q{Lipgloss::Style.new.render("abc").frozen?}
  add "misc.nul_in_string", %q{Lipgloss::Style.new.render("a\0b")}
end
