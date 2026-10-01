# frozen_string_literal: true

LipglossCases.define("color") do
  hexes = {
    "red6" => "#ff0000", "green6" => "#00ff00", "blue6" => "#0000ff", "white6" => "#ffffff", "black6" => "#000000",
    "upper6" => "#7D56F4", "gray6" => "#808080", "dark_gray6" => "#1a1a1a", "light_gray6" => "#e0e0e0",
    "orange6" => "#ff8800", "teal6" => "#008080", "pink6" => "#ff69b4", "near_cube6" => "#5f87af",
    "red3" => "#f00", "mixed3" => "#a3c", "upper3" => "#ABC", "white3" => "#fff"
  }
  hexes.each do |name, hex|
    add "color.fg_hex_#{name}", %{Lipgloss::Style.new.foreground("#{hex}").render("x")}
    add "color.bg_hex_#{name}", %{Lipgloss::Style.new.background("#{hex}").render("x")}
  end

  (0..15).each do |n|
    add "color.fg_ansi_#{n}", %{Lipgloss::Style.new.foreground("#{n}").render("x")}
    add "color.bg_ansi_#{n}", %{Lipgloss::Style.new.background("#{n}").render("x")}
  end
  [16, 21, 52, 100, 124, 196, 202, 226, 231, 232, 240, 244, 250, 255].each do |n|
    add "color.fg_256_#{n}", %{Lipgloss::Style.new.foreground("#{n}").render("x")}
    add "color.bg_256_#{n}", %{Lipgloss::Style.new.background("#{n}").render("x")}
  end

  # --- invalid / odd values --------------------------------------------------------------------------
  {
    "empty" => "", "name" => "red", "bad_hex" => "#gg0000", "short_hex" => "#12", "long_hex" => "#1234567",
    # "256" and "999" are left out: they crash the real gem (Go index out of range) under the ansi profile.
    "no_hash" => "ff0000", "negative" => "-1", "space" => " 1",
    "four_hex" => "#abcd", "hash_only" => "#", "float" => "1.5", "leading_zero" => "007"
  }.each do |name, value|
    add "color.fg_invalid_#{name}", %{Lipgloss::Style.new.foreground(#{value.inspect}).render("x")}
    add "color.bg_invalid_#{name}", %{Lipgloss::Style.new.background(#{value.inspect}).render("x")}
  end
  add "color.fg_nil", %q{Lipgloss::Style.new.foreground(nil)}
  add "color.fg_integer", %q{Lipgloss::Style.new.foreground(1)}
  add "color.fg_symbol", %q{Lipgloss::Style.new.foreground(:red)}
  add "color.bg_integer", %q{Lipgloss::Style.new.background(1)}
  add "color.fg_hash", %q{Lipgloss::Style.new.foreground({light: "#000", dark: "#fff"})}

  # --- adaptive --------------------------------------------------------------------------------------
  add "color.adaptive_fg", %q{Lipgloss::Style.new.foreground(Lipgloss::AdaptiveColor.new(light: "#0000ff", dark: "#ffff00")).render("x")}
  add "color.adaptive_bg", %q{Lipgloss::Style.new.background(Lipgloss::AdaptiveColor.new(light: "#0000ff", dark: "#ffff00")).render("x")}
  add "color.adaptive_ansi", %q{Lipgloss::Style.new.foreground(Lipgloss::AdaptiveColor.new(light: "1", dark: "2")).render("x")}
  add "color.adaptive_256", %q{Lipgloss::Style.new.foreground(Lipgloss::AdaptiveColor.new(light: "21", dark: "226")).render("x")}
  add "color.adaptive_empty_light", %q{Lipgloss::Style.new.foreground(Lipgloss::AdaptiveColor.new(light: "", dark: "#ff0000")).render("x")}
  add "color.adaptive_invalid", %q{Lipgloss::Style.new.foreground(Lipgloss::AdaptiveColor.new(light: "zz", dark: "yy")).render("x")}
  add "color.adaptive_to_h", %q{Lipgloss::AdaptiveColor.new(light: "#000", dark: "#fff").to_h.transform_keys(&:to_s)}
  add "color.adaptive_readers", %q{c = Lipgloss::AdaptiveColor.new(light: "#000", dark: "#fff"); [c.light, c.dark]}
  add "color.adaptive_missing_kw", %q{Lipgloss::AdaptiveColor.new(light: "#000")}
  add "color.adaptive_integer_values", %q{Lipgloss::Style.new.foreground(Lipgloss::AdaptiveColor.new(light: 1, dark: 2))}
  add "color.adaptive_duck_typed", %q{o = Struct.new(:light, :dark).new("#ff0000", "#00ff00"); Lipgloss::Style.new.foreground(o).render("x")}
  add "color.adaptive_with_text", %q{Lipgloss::Style.new.foreground(Lipgloss::AdaptiveColor.new(light: "#333333", dark: "#cccccc")).background(Lipgloss::AdaptiveColor.new(light: "#eeeeee", dark: "#111111")).padding(0, 1).render("Hi")}

  # --- complete --------------------------------------------------------------------------------------
  add "color.complete_fg", %q{Lipgloss::Style.new.foreground(Lipgloss::CompleteColor.new(true_color: "#0000ff", ansi256: 21, ansi: :blue)).render("x")}
  add "color.complete_bg", %q{Lipgloss::Style.new.background(Lipgloss::CompleteColor.new(true_color: "#ff8800", ansi256: "208", ansi: "3")).render("x")}
  add "color.complete_symbols", %q{Lipgloss::Style.new.foreground(Lipgloss::CompleteColor.new(true_color: "#ff0000", ansi256: :bright_red, ansi: :red)).render("x")}
  add "color.complete_mismatched", %q{Lipgloss::Style.new.foreground(Lipgloss::CompleteColor.new(true_color: "#00ff00", ansi256: 196, ansi: 4)).render("x")}
  add "color.complete_empty_true", %q{Lipgloss::Style.new.foreground(Lipgloss::CompleteColor.new(true_color: "", ansi256: 196, ansi: 4)).render("x")}
  add "color.complete_to_h", %q{Lipgloss::CompleteColor.new(true_color: "#0000ff", ansi256: 21, ansi: :blue).to_h.transform_keys(&:to_s)}
  add "color.complete_readers", %q{c = Lipgloss::CompleteColor.new(true_color: "#0000ff", ansi256: :bright_white, ansi: 7); [c.true_color, c.ansi256, c.ansi]}
  add "color.complete_unknown_symbol", %q{Lipgloss::CompleteColor.new(true_color: "#000", ansi256: :pink, ansi: :red)}
  add "color.complete_float", %q{Lipgloss::CompleteColor.new(true_color: "#000", ansi256: 1.5, ansi: :red)}
  add "color.complete_nil", %q{Lipgloss::CompleteColor.new(true_color: "#000", ansi256: 1, ansi: nil)}
  add "color.complete_true_color_integer", %q{Lipgloss::Style.new.foreground(Lipgloss::CompleteColor.new(true_color: 5, ansi256: 1, ansi: 1))}
  add "color.ansi_colors_table", %q{Lipgloss::ANSIColor::COLORS.transform_keys(&:to_s)}
  add "color.ansi_resolve_symbol", %q{Lipgloss::ANSIColor.resolve(:bright_cyan)}
  add "color.ansi_resolve_string", %q{Lipgloss::ANSIColor.resolve("42")}
  add "color.ansi_resolve_integer", %q{Lipgloss::ANSIColor.resolve(200)}
  add "color.ansi_resolve_unknown", %q{Lipgloss::ANSIColor.resolve(:nope)}
  add "color.ansi_resolve_array", %q{Lipgloss::ANSIColor.resolve([])}

  # --- complete adaptive -----------------------------------------------------------------------------
  add "color.complete_adaptive_fg", %q{Lipgloss::Style.new.foreground(Lipgloss::CompleteAdaptiveColor.new(light: Lipgloss::CompleteColor.new(true_color: "#000000", ansi256: :black, ansi: :black), dark: Lipgloss::CompleteColor.new(true_color: "#ffffff", ansi256: 231, ansi: :bright_white))).render("x")}
  add "color.complete_adaptive_bg", %q{Lipgloss::Style.new.background(Lipgloss::CompleteAdaptiveColor.new(light: Lipgloss::CompleteColor.new(true_color: "#ff0000", ansi256: 196, ansi: 1), dark: Lipgloss::CompleteColor.new(true_color: "#0000ff", ansi256: 21, ansi: 4))).render("x")}
  add "color.complete_adaptive_to_h", %q{Lipgloss::CompleteAdaptiveColor.new(light: Lipgloss::CompleteColor.new(true_color: "#000", ansi256: 0, ansi: 0), dark: Lipgloss::CompleteColor.new(true_color: "#fff", ansi256: 15, ansi: 15)).to_h.to_a.map { |k, v| [k.to_s, v.transform_keys(&:to_s)] }}
  add "color.complete_adaptive_half", %q{Lipgloss::Style.new.foreground(Lipgloss::CompleteAdaptiveColor.new(light: Lipgloss::CompleteColor.new(true_color: "#000", ansi256: 0, ansi: 0), dark: "#ff0000")).render("x")}

  # --- colors on other parts --------------------------------------------------------------------------
  add "color.fg_bg", %q{Lipgloss::Style.new.foreground("#ffffff").background("#ff0000").render("hi")}
  add "color.fg_bg_ansi", %q{Lipgloss::Style.new.foreground("15").background("1").render("hi")}
  add "color.border_and_text", %q{Lipgloss::Style.new.border(:normal).border_foreground("#00ff00").border_background("#000080").foreground("#ff0000").render("hi")}
  add "color.margin_bg_hex", %q{Lipgloss::Style.new.margin(0, 1).margin_background("#ff00ff").render("hi")}
  add "color.margin_bg_256", %q{Lipgloss::Style.new.margin(0, 1).margin_background("99").render("hi")}
  add "color.margin_bg_invalid", %q{Lipgloss::Style.new.margin(0, 1).margin_background("nope").render("hi")}
  add "color.border_fg_256", %q{Lipgloss::Style.new.border(:rounded).border_foreground("99").render("hi")}
  add "color.border_bg_ansi", %q{Lipgloss::Style.new.border(:rounded).border_background("5").render("hi")}
  add "color.reverse_with_colors", %q{Lipgloss::Style.new.reverse(true).foreground("1").background("2").render("hi")}
  add "color.has_dark_background", %q{Lipgloss.has_dark_background?}
end
