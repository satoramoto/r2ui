# frozen_string_literal: true

require "test_helper"

# s18-theme: `theme` restyles the canvas from lipgloss options; `style` builds a Lipgloss::Style.
# The expected bytes come from lipgloss itself (the spec) for the same options and colour profile.
class ThemeTest < Minitest::Test
  PROFILES = %i[true_color ansi256 ansi].freeze

  def setup
    R2UI.reset!
    R2UI::Ext::Theme.require_lipgloss!
    profile(:true_color)
  end

  def teardown = profile(nil)

  def profile(name) = R2UI::Compat::Gloss::Renderer.color_profile = name

  # The SGR parameters lipgloss itself renders for a style.
  def lipgloss_sgr(style) = style.render("x")[/\A\e\[([0-9;:]*)m/, 1]

  def themed_app
    R2UI.dashboard do
      theme do
        title foreground: "#7D56F4", bold: true
        focus foreground: "#04B575"
      end
      row { panel(:hello, resource: nil) { view { "hi" } } }
    end
    R2UI::App.new(R2UI.registry)
  end

  def ansi(app) = app.frame(40, 6).ansi_lines.join("\n")

  def test_theme_restyles_canvas_styles_with_lipgloss_colours
    app = themed_app
    title = lipgloss_sgr(Lipgloss::Style.new.foreground("#7D56F4").bold(true))
    focus = lipgloss_sgr(Lipgloss::Style.new.foreground("#04B575"))

    assert_includes ansi(app), "\e[0;#{title}m Hello "
    assert_includes ansi(app), "\e[0;#{focus}m╭─"
    assert_match(/\e\[0;1;38;2;\d+;\d+;\d+m Hello /, ansi(app), "truecolor: bold plus a 24-bit foreground")
  end

  def test_colour_output_matches_lipgloss_for_each_profile
    app = themed_app
    PROFILES.each do |name|
      profile(name)
      expected = lipgloss_sgr(Lipgloss::Style.new.foreground("#7D56F4").bold(true))
      assert_includes ansi(app), "\e[0;#{expected}m Hello ", "profile #{name}"
    end

    profile(:ascii)
    refute_includes ansi(app), "\e[0;1;36m Hello ", "no colour profile: lipgloss styles nothing, so neither does the theme"
    assert_includes ansi(app), "\e[0;0m Hello "
  end

  def test_all_text_options
    R2UI.dashboard do
      theme { title foreground: "201", background: "#04B575", bold: true, italic: true, underline: true, reverse: true }
      row { panel(:hello, resource: nil) { view { "hi" } } }
    end
    expected = Lipgloss::Style.new.foreground("201").background("#04B575").bold(true).italic(true).underline(true)
                              .reverse(true)

    assert_includes ansi(R2UI::App.new(R2UI.registry)), "\e[0;#{lipgloss_sgr(expected)}m Hello "
  end

  def test_unthemed_styles_keep_their_defaults
    out = ansi(themed_app)

    assert_includes out, "\e[0;7m ", "the status bar keeps the default palette"
    R2UI.reset!
    R2UI.dashboard { row { panel(:hello, resource: nil) { view { "hi" } } } }
    assert_includes ansi(R2UI::App.new(R2UI.registry)), "\e[0;1;36m Hello "
  end

  def test_theme_twice_merges_and_later_wins
    R2UI.dashboard do
      theme { title foreground: "#7D56F4"; focus foreground: "#FFAA00" }
      theme { title foreground: "#FF0000", italic: true }
      row { panel(:hello, resource: nil) { view { "hi" } } }
    end
    out = ansi(R2UI::App.new(R2UI.registry))

    assert_includes out, "\e[0;#{lipgloss_sgr(Lipgloss::Style.new.foreground("#FF0000").italic(true))}m Hello "
    assert_includes out, "\e[0;#{lipgloss_sgr(Lipgloss::Style.new.foreground("#FFAA00"))}m╭─"
  end

  def test_style_helper_returns_a_lipgloss_style_for_view_blocks
    R2UI.dashboard do
      row do
        panel :hello, resource: nil do
          view { style(foreground: "#FF5F87", italic: true).render("pink") }
          view { style(bold: true, padding: [0, 2]).render("pad") }
        end
      end
    end
    app = R2UI::App.new(R2UI.registry)
    pink = lipgloss_sgr(Lipgloss::Style.new.foreground("#FF5F87").italic(true))

    assert_includes ansi(app), "\e[0;#{pink}mpink"
    assert_match(/│  pad/, app.frame(40, 6).plain_lines.join("\n"))
    assert_kind_of Lipgloss::Style, R2UI::Context.new(app).style(bold: true)
    assert_equal Lipgloss::Style.new.bold(true).render("b"), R2UI::Context.new(app).style(bold: true).render("b")
  end

  def test_bad_definitions_raise
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { theme } }
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { theme { title padding: 1 } } }
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { theme { title "#fff" } } }
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { theme { title } } }
    assert_raises(ArgumentError) { R2UI::Ext::Theme.style(colour: "#fff") }
  end
end
