# frozen_string_literal: true

LipglossCases.define("table") do
  base = %q{Lipgloss::Table.new.headers(["Name", "Lang"]).rows([["Alice", "Ruby"], ["Bob", "Go"], ["Carol", "Rust"]])}

  add "table.basic", %{#{base}.render}
  add "table.to_s", %{#{base}.to_s}
  add "table.empty", %q{Lipgloss::Table.new.render}
  add "table.empty_to_s", %q{Lipgloss::Table.new.to_s}
  add "table.headers_only", %q{Lipgloss::Table.new.headers(["A", "B", "C"]).render}
  add "table.rows_only", %q{Lipgloss::Table.new.rows([["1", "2"], ["3", "4"]]).render}
  add "table.single_cell", %q{Lipgloss::Table.new.rows([["x"]]).render}
  add "table.row_appends", %q{Lipgloss::Table.new.headers(["A", "B"]).row(["1", "2"]).row(["3", "4"]).render}
  add "table.rows_then_row", %q{Lipgloss::Table.new.rows([["1", "2"]]).row(["3", "4"]).render}
  add "table.rows_twice", %q{Lipgloss::Table.new.rows([["1"]]).rows([["2"]]).render}
  add "table.headers_twice", %q{Lipgloss::Table.new.headers(["A"]).headers(["B", "C"]).rows([["1", "2"]]).render}
  add "table.ragged_rows", %q{Lipgloss::Table.new.headers(["A", "B", "C"]).rows([["1"], ["2", "3", "4"], ["5", "6"]]).render}
  add "table.more_cells_than_headers", %q{Lipgloss::Table.new.headers(["A"]).rows([["1", "2", "3"]]).render}
  add "table.empty_cells", %q{Lipgloss::Table.new.headers(["", "B"]).rows([["", ""], ["x", ""]]).render}
  add "table.empty_row", %q{Lipgloss::Table.new.headers(["A", "B"]).row([]).render}
  add "table.multiline_cells", %q{Lipgloss::Table.new.headers(["A", "B"]).rows([["line1\nline2", "x"], ["y", "a\nb\nc"]]).render}
  add "table.wide_content", %q{Lipgloss::Table.new.headers(["名前", "言語"]).rows([["日本語", "😀"], ["한글", "ok"]]).render}
  add "table.ansi_content", %q{Lipgloss::Table.new.headers(["A"]).rows([["\e[31mred\e[0m"], ["plain"]]).render}
  add "table.styled_cells", %q{Lipgloss::Table.new.rows([[Lipgloss::Style.new.bold(true).render("b"), "x"]]).render}
  add "table.long_rows", %q{Lipgloss::Table.new.headers(["#", "Item"]).rows((1..12).map { |i| [i.to_s, "item #{i}"] }).render}
  add "table.non_string_cells", %q{Lipgloss::Table.new.rows([[1, 2]]).render}
  add "table.non_string_headers", %q{Lipgloss::Table.new.headers([:a, :b]).rows([["1", "2"]]).render}
  add "table.nil_cell", %q{Lipgloss::Table.new.rows([["a", nil]]).render}
  add "table.headers_not_array", %q{Lipgloss::Table.new.headers("A")}
  add "table.row_not_array", %q{Lipgloss::Table.new.row("A")}
  add "table.rows_not_array", %q{Lipgloss::Table.new.rows("A")}
  add "table.rows_flat", %q{Lipgloss::Table.new.rows(["a", "b"]).render}
  add "table.new_with_args", %q{Lipgloss::Table.new(1)}
  add "table.immutable", %q{t = Lipgloss::Table.new.headers(["A"]); t.row(["1"]); t.render}
  add "table.class_of_chain", %q{Lipgloss::Table.new.headers(["A"]).class.name}

  # --- borders -------------------------------------------------------------------------------------
  %w[normal rounded thick double hidden block outer_half_block inner_half_block ascii markdown].each do |b|
    add "table.border_#{b}", %{#{base}.border(:#{b}).render}
  end
  add "table.border_unknown", %{#{base}.border(:nope).render}
  add "table.border_string", %{#{base}.border("double").render}
  add "table.border_constant", %{#{base}.border(Lipgloss::THICK_BORDER).render}
  %w[top bottom left right header column row].each do |side|
    add "table.border_#{side}_false", %{#{base}.border_#{side}(false).render}
    add "table.border_#{side}_true", %{#{base}.border_#{side}(true).render}
  end
  add "table.border_row_markdown", %{#{base}.border(:markdown).border_row(true).render}
  add "table.no_outer", %{#{base}.border_top(false).border_bottom(false).border_left(false).border_right(false).render}
  add "table.no_borders", %{#{base}.border_top(false).border_bottom(false).border_left(false).border_right(false).border_header(false).border_column(false).render}
  add "table.markdown_no_outer", %{#{base}.border(:markdown).border_top(false).border_bottom(false).render}
  add "table.border_style", %{#{base}.border_style(Lipgloss::Style.new.foreground("#ff00ff")).render}
  add "table.border_style_bg", %{#{base}.border_style(Lipgloss::Style.new.foreground("1").background("4")).render}
  add "table.border_style_bold", %{#{base}.border(:double).border_style(Lipgloss::Style.new.bold(true)).render}
  add "table.border_style_bad", %q{Lipgloss::Table.new.border_style("red")}
  add "table.border_row_no_headers", %q{Lipgloss::Table.new.rows([["a", "b"], ["c", "d"]]).border_row(true).render}

  # --- width / height / offset / wrap -----------------------------------------------------------------
  [5, 10, 20, 30, 40].each do |w|
    add "table.width_#{w}", %{#{base}.width(#{w}).render}
  end
  add "table.width_zero", %{#{base}.width(0).render}
  add "table.width_negative", %{#{base}.width(-1).render}
  add "table.width_long_text", %q{Lipgloss::Table.new.headers(["Desc", "N"]).rows([["a long description that needs wrapping", "1"]]).width(24).render}
  add "table.width_long_text_nowrap", %q{Lipgloss::Table.new.headers(["Desc", "N"]).rows([["a long description that needs wrapping", "1"]]).width(24).wrap(false).render}
  add "table.wrap_true", %q{Lipgloss::Table.new.rows([["aaa bbb ccc ddd", "x"]]).width(12).wrap(true).render}
  add "table.wrap_false", %q{Lipgloss::Table.new.rows([["aaa bbb ccc ddd", "x"]]).width(12).wrap(false).render}
  add "table.wrap_wide", %q{Lipgloss::Table.new.rows([["日本語のテキストです", "x"]]).width(12).render}
  [1, 3, 4, 5, 6, 8, 20].each do |h|
    add "table.height_#{h}", %{#{base}.height(#{h}).render}
  end
  add "table.height_long", %q{Lipgloss::Table.new.headers(["#"]).rows((1..10).map { |i| [i.to_s] }).height(7).render}
  add "table.height_negative", %{#{base}.height(-2).render}
  [0, 1, 2, 3, 5].each do |o|
    add "table.offset_#{o}", %{#{base}.offset(#{o}).render}
  end
  # offset(-1) is left out: it crashes the real gem (Go index out of range in constructRow).
  add "table.offset_height", %q{Lipgloss::Table.new.headers(["#"]).rows((1..10).map { |i| [i.to_s] }).offset(3).height(6).render}
  add "table.width_height", %{#{base}.width(30).height(6).render}
  add "table.width_string", %q{Lipgloss::Table.new.width("10")}

  # --- clear_rows ----------------------------------------------------------------------------------
  add "table.clear_rows", %{#{base}.clear_rows.render}
  add "table.clear_rows_then_add", %{#{base}.clear_rows.row(["Dave", "Zig"]).render}
  add "table.clear_rows_empty", %q{Lipgloss::Table.new.clear_rows.render}

  # --- style_func ----------------------------------------------------------------------------------
  add "table.style_func_header", %{#{base}.style_func(rows: 3, columns: 2) { |r, c| r == Lipgloss::Table::HEADER_ROW ? Lipgloss::Style.new.bold(true) : nil }.render}
  add "table.style_func_zebra", %{#{base}.style_func(rows: 3, columns: 2) { |r, c| r.even? ? Lipgloss::Style.new.background("#333333") : Lipgloss::Style.new.background("#444444") }.render}
  add "table.style_func_columns", %{#{base}.style_func(rows: 3, columns: 2) { |r, c| c.zero? ? Lipgloss::Style.new.foreground("#00ff00") : Lipgloss::Style.new.foreground("#ff0000") }.render}
  add "table.style_func_padding", %{#{base}.style_func(rows: 3, columns: 2) { |r, c| Lipgloss::Style.new.padding(0, 1) }.render}
  add "table.style_func_width", %{#{base}.style_func(rows: 3, columns: 2) { |r, c| c == 1 ? Lipgloss::Style.new.width(10) : nil }.render}
  add "table.style_func_align", %{#{base}.style_func(rows: 3, columns: 2) { |r, c| Lipgloss::Style.new.width(8).align(:right) }.render}
  add "table.style_func_align_center", %{#{base}.style_func(rows: 3, columns: 2) { |r, c| Lipgloss::Style.new.padding(0, 1).align(:center) }.render}
  add "table.style_func_all_nil", %{#{base}.style_func(rows: 3, columns: 2) { |r, c| nil }.render}
  add "table.style_func_fewer_rows", %{#{base}.style_func(rows: 1, columns: 1) { |r, c| Lipgloss::Style.new.bold(true) }.render}
  add "table.style_func_more_rows", %{#{base}.style_func(rows: 9, columns: 5) { |r, c| Lipgloss::Style.new.italic(true) }.render}
  add "table.style_func_border", %{#{base}.style_func(rows: 3, columns: 2) { |r, c| Lipgloss::Style.new.border(:normal) }.render}
  add "table.style_func_margin", %{#{base}.style_func(rows: 3, columns: 2) { |r, c| Lipgloss::Style.new.margin(0, 1) }.render}
  add "table.style_func_height", %{#{base}.style_func(rows: 3, columns: 2) { |r, c| Lipgloss::Style.new.height(2) }.render}
  add "table.style_func_with_width", %{#{base}.width(30).style_func(rows: 3, columns: 2) { |r, c| Lipgloss::Style.new.padding(0, 1) }.render}
  add "table.style_func_calls", %{calls = []; #{base}.style_func(rows: 2, columns: 2) { |r, c| calls << [r, c]; nil }; calls}
  add "table.style_func_no_block", %{#{base}.style_func(rows: 1, columns: 1)}
  add "table.style_func_negative_rows", %{#{base}.style_func(rows: -1, columns: 1) { nil }}
  add "table.style_func_zero_columns", %{#{base}.style_func(rows: 1, columns: 0) { nil }}
  add "table.style_func_missing_kw", %{#{base}.style_func(rows: 1) { nil }}
  add "table.style_func_bad_style", %{#{base}.style_func(rows: 1, columns: 1) { "bold" }}
  add "table.style_func_map_private", %{#{base}._style_func_map({"0,0" => Lipgloss::Style.new.bold(true)}).render}
  add "table.style_func_map_not_hash", %q{Lipgloss::Table.new._style_func_map([])}
  add "table.header_row_constant", %q{Lipgloss::Table::HEADER_ROW}
  add "table.styled_full", %{#{base}.border(:rounded).border_style(Lipgloss::Style.new.foreground("99")).style_func(rows: 3, columns: 2) { |r, c| r == -1 ? Lipgloss::Style.new.bold(true).foreground("212").padding(0, 1) : Lipgloss::Style.new.padding(0, 1) }.width(30).render}
end
