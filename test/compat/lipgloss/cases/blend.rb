# frozen_string_literal: true

LipglossCases.define("blend") do
  pairs = {
    "red_blue" => %w[#ff0000 #0000ff], "black_white" => %w[#000000 #ffffff], "purple_green" => %w[#7D56F4 #04B575],
    "short_hex" => %w[#f00 #0f0], "same" => %w[#123456 #123456], "upper" => %w[#FF8800 #0088FF]
  }
  ts = { "0" => "0.0", "025" => "0.25", "05" => "0.5", "075" => "0.75", "1" => "1.0" }

  pairs.each do |pname, (a, b)|
    %w[luv rgb hcl].each do |mode|
      ts.each do |tname, t|
        add "blend.#{mode}_#{pname}_#{tname}", %{Lipgloss::ColorBlend.blend_#{mode}("#{a}", "#{b}", #{t})}
      end
    end
    add "blend.default_#{pname}", %{Lipgloss::ColorBlend.blend("#{a}", "#{b}", 0.3)}
    add "blend.blends_#{pname}", %{Lipgloss::ColorBlend.blends("#{a}", "#{b}", 5)}
  end

  %w[luv rgb hcl].each do |mode|
    add "blend.blend_mode_#{mode}", %{Lipgloss::ColorBlend.blend("#ff0000", "#00ff00", 0.4, mode: :#{mode})}
    add "blend.blends_mode_#{mode}", %{Lipgloss::ColorBlend.blends("#ff0000", "#00ff00", 6, mode: :#{mode})}
    add "blend.grid_mode_#{mode}", %{Lipgloss::ColorBlend.grid("#ff0000", "#00ff00", "#0000ff", "#ffffff", 3, 3, mode: :#{mode})}
  end
  add "blend.mode_constants", %q{[Lipgloss::ColorBlend::LUV, Lipgloss::ColorBlend::RGB, Lipgloss::ColorBlend::HCL].map(&:to_s)}
  add "blend.mode_constant_used", %q{Lipgloss::ColorBlend.blend("#000000", "#ffffff", 0.5, mode: Lipgloss::ColorBlend::HCL)}
  add "blend.mode_unknown", %q{Lipgloss::ColorBlend.blend("#000000", "#ffffff", 0.5, mode: :xyz)}
  add "blend.mode_nil", %q{Lipgloss::ColorBlend.blend("#000000", "#ffffff", 0.5, mode: nil)}
  add "blend.mode_string", %q{Lipgloss::ColorBlend.blend("#000000", "#ffffff", 0.5, mode: "rgb")}
  add "blend.extra_kwarg", %q{Lipgloss::ColorBlend.blend("#000000", "#ffffff", 0.5, foo: 1)}

  # --- t edge cases --------------------------------------------------------------------------------
  add "blend.t_negative", %q{Lipgloss::ColorBlend.blend_rgb("#ff0000", "#0000ff", -0.5)}
  add "blend.t_above_one", %q{Lipgloss::ColorBlend.blend_rgb("#ff0000", "#0000ff", 1.5)}
  add "blend.t_integer", %q{Lipgloss::ColorBlend.blend_luv("#ff0000", "#0000ff", 1)}
  add "blend.t_luv_above_one", %q{Lipgloss::ColorBlend.blend_luv("#ff0000", "#0000ff", 2.0)}
  add "blend.t_hcl_negative", %q{Lipgloss::ColorBlend.blend_hcl("#ff0000", "#0000ff", -1.0)}
  add "blend.t_string", %q{Lipgloss::ColorBlend.blend_rgb("#ff0000", "#0000ff", "0.5")}
  add "blend.t_nil", %q{Lipgloss::ColorBlend.blend_rgb("#ff0000", "#0000ff", nil)}

  # --- invalid colors ------------------------------------------------------------------------------
  add "blend.invalid_first", %q{Lipgloss::ColorBlend.blend_rgb("nope", "#0000ff", 0.5)}
  add "blend.invalid_second", %q{Lipgloss::ColorBlend.blend_rgb("#ff0000", "nope", 0.5)}
  add "blend.invalid_ansi", %q{Lipgloss::ColorBlend.blend_luv("1", "2", 0.5)}
  add "blend.invalid_empty", %q{Lipgloss::ColorBlend.blend_hcl("", "#fff", 0.5)}
  add "blend.invalid_no_hash", %q{Lipgloss::ColorBlend.blend("ff0000", "#0000ff", 0.5)}
  add "blend.invalid_four_digit", %q{Lipgloss::ColorBlend.blend("#ff00", "#0000ff", 0.5)}
  add "blend.uppercase_out", %q{Lipgloss::ColorBlend.blend_rgb("#AABBCC", "#AABBCC", 0.5)}
  add "blend.non_string", %q{Lipgloss::ColorBlend.blend_rgb(1, "#0000ff", 0.5)}
  add "blend.non_string_second", %q{Lipgloss::ColorBlend.blend(:red, :blue, 0.5)}
  add "blend.wrong_arity", %q{Lipgloss::ColorBlend.blend_rgb("#fff", "#000")}
  add "blend.blend_wrong_arity", %q{Lipgloss::ColorBlend.blend("#fff")}

  # --- blends edge cases ---------------------------------------------------------------------------
  [0, 1, 2, 3, 10].each do |n|
    add "blend.blends_steps_#{n}", %{Lipgloss::ColorBlend.blends("#ff0000", "#0000ff", #{n})}
  end
  add "blend.blends_rgb_steps_4", %q{Lipgloss::ColorBlend.blends("#000000", "#ffffff", 4, mode: :rgb)}
  add "blend.blends_invalid", %q{Lipgloss::ColorBlend.blends("bad", "#0000ff", 3)}
  add "blend.blends_invalid_second", %q{Lipgloss::ColorBlend.blends("#ff0000", "bad", 3)}
  add "blend.blends_float_steps", %q{Lipgloss::ColorBlend.blends("#ff0000", "#0000ff", 3.9)}
  add "blend.blends_string_steps", %q{Lipgloss::ColorBlend.blends("#ff0000", "#0000ff", "3")}
  add "blend.blends_non_string", %q{Lipgloss::ColorBlend.blends(nil, "#0000ff", 3)}

  # --- grid ----------------------------------------------------------------------------------------
  add "blend.grid_2x2", %q{Lipgloss::ColorBlend.grid("#ff0000", "#00ff00", "#0000ff", "#ffffff", 2, 2)}
  add "blend.grid_4x3", %q{Lipgloss::ColorBlend.grid("#000000", "#ff0000", "#0000ff", "#ffffff", 4, 3)}
  add "blend.grid_1x1", %q{Lipgloss::ColorBlend.grid("#ff0000", "#00ff00", "#0000ff", "#ffffff", 1, 1)}
  add "blend.grid_1x3", %q{Lipgloss::ColorBlend.grid("#ff0000", "#00ff00", "#0000ff", "#ffffff", 1, 3)}
  add "blend.grid_3x1", %q{Lipgloss::ColorBlend.grid("#ff0000", "#00ff00", "#0000ff", "#ffffff", 3, 1)}
  add "blend.grid_0x2", %q{Lipgloss::ColorBlend.grid("#ff0000", "#00ff00", "#0000ff", "#ffffff", 0, 2)}
  add "blend.grid_2x0", %q{Lipgloss::ColorBlend.grid("#ff0000", "#00ff00", "#0000ff", "#ffffff", 2, 0)}
  add "blend.grid_invalid", %q{Lipgloss::ColorBlend.grid("#ff0000", "#00ff00", "x", "#ffffff", 2, 2)}
  add "blend.grid_invalid_last", %q{Lipgloss::ColorBlend.grid("#ff0000", "#00ff00", "#0000ff", "", 2, 2)}
  add "blend.grid_short_hex", %q{Lipgloss::ColorBlend.grid("#f00", "#0f0", "#00f", "#fff", 3, 2)}
  add "blend.grid_non_string", %q{Lipgloss::ColorBlend.grid("#f00", "#0f0", "#00f", 4, 3, 2)}
  add "blend.grid_wrong_arity", %q{Lipgloss::ColorBlend.grid("#f00", "#0f0", "#00f", "#fff", 3)}
end
