# frozen_string_literal: true

require "test_helper"
require_relative "../compat/bubbletea/pty_helper"

# s14-mouse: `mouse :cell` / `:all` turns on mouse reporting; a left click focuses the panel under
# it and selects the clicked table row; the wheel moves the selection; `on_click` runs for clicks;
# reporting is turned off on exit.
class MouseTest < Minitest::Test
  Mouse = Bubbletea::MouseMessage
  # What a terminal sends for the left button (SGR button 0). Bubbletea 0.1.4 passes the raw
  # number through, so a real left click arrives as button 0.
  LEFT = 0

  WIDTH = 80
  HEIGHT = 24

  def setup
    R2UI.reset!
    Fixtures.define_processes
  end

  def app_with(&block)
    R2UI.dashboard(&block)
    app = R2UI::App.new(R2UI.registry)
    app.feeds.each_value(&:refresh!)
    app.frame(WIDTH, HEIGHT)
    app
  end

  def standard_app
    app_with do
      mouse :cell
      row(height: 3) { panel(:clock, resource: nil) { view { "clock" } } }
      row { panel :process }
    end
  end

  def text(app) = app.frame(WIDTH, HEIGHT).plain_lines

  # [x, y] of the first cell showing `needle` in the current frame.
  def where(app, needle)
    text(app).each_with_index do |line, y|
      x = line.index(needle)
      return [x, y] if x
    end
    flunk "#{needle.inspect} not on screen:\n#{text(app).join("\n")}"
  end

  def press(app, x, y, button: LEFT) = app.update(Mouse.new(x:, y:, button:, action: Mouse::ACTION_PRESS)).last

  def wheel(app, x, y, button) = press(app, x, y, button:)

  def selected_name(app) = app.selected_rows.first&.name

  def test_mouse_turns_on_cell_or_all_motion_reporting
    R2UI.dashboard { mouse :cell }
    assert R2UI::App.new(R2UI.registry).program_options[:mouse_cell_motion]

    R2UI.reset!
    R2UI.dashboard { mouse :all }
    options = R2UI::App.new(R2UI.registry).program_options
    assert options[:mouse_all_motion]
    refute options[:mouse_cell_motion]

    R2UI.reset!
    R2UI.dashboard { mouse }
    assert R2UI::App.new(R2UI.registry).program_options[:mouse_cell_motion], "default mode is :cell"
  end

  def test_no_mouse_means_no_reporting_and_clicks_are_ignored
    app = app_with do
      row(height: 3) { panel(:clock, resource: nil) { view { "clock" } } }
      row { panel :process }
    end
    options = app.program_options
    refute options[:mouse_cell_motion]
    refute options[:mouse_all_motion]

    press(app, *where(app, "clock"))
    assert_equal :process, app.focus.name
  end

  def test_unknown_mode_raises
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { mouse :pixels } }
  end

  def test_left_click_focuses_the_panel_under_it
    app = standard_app
    assert_equal :process, app.focus.name

    press(app, *where(app, "clock"))
    assert_equal :clock, app.focus.name

    press(app, *where(app, "Process "))
    assert_equal :process, app.focus.name
  end

  def test_other_buttons_and_releases_do_not_focus
    app = standard_app
    x, y = where(app, "clock")

    press(app, x, y, button: Mouse::BUTTON_RIGHT)
    app.update(Mouse.new(x:, y:, button: LEFT, action: Mouse::ACTION_RELEASE))
    app.update(Mouse.new(x:, y:, button: LEFT, action: Mouse::ACTION_MOTION))

    assert_equal :process, app.focus.name
  end

  def test_left_click_selects_the_clicked_table_row
    app = standard_app
    press(app, *where(app, "clock"))

    press(app, *where(app, "codex"))

    assert_equal :process, app.focus.name
    assert_equal "codex", selected_name(app)
    row = text(app).find { |l| l.include?("codex") }
    assert_includes app.frame(WIDTH, HEIGHT).ansi_lines.find { |l| l.include?("codex") }, "\e[0;7;36m",
                    "the clicked row is drawn selected: #{row}"

    press(app, *where(app, "zsh"))
    assert_equal "zsh", selected_name(app)
  end

  def test_click_finds_rows_below_other_items_in_the_panel
    app = app_with do
      mouse :cell
      row do
        panel :process do
          view { "one\ntwo\nthree" }
          table
        end
      end
    end

    press(app, *where(app, "codex"))
    assert_equal "codex", selected_name(app)
  end

  def test_click_on_the_header_or_below_the_rows_keeps_the_selection
    app = standard_app
    press(app, *where(app, "codex"))

    press(app, *where(app, "Memory"))
    assert_equal "codex", selected_name(app)

    x, y = where(app, "zsh")
    press(app, x, y + 3)
    assert_equal "codex", selected_name(app)
  end

  def test_wheel_moves_the_selection
    app = standard_app
    first = selected_name(app)
    x, y = where(app, "codex")

    wheel(app, x, y, Mouse::BUTTON_WHEEL_DOWN)
    text(app)
    second = selected_name(app)
    refute_equal first, second

    wheel(app, x, y, Mouse::BUTTON_WHEEL_UP)
    text(app)
    assert_equal first, selected_name(app)

    wheel(app, x, y, Mouse::BUTTON_WHEEL_UP)
    assert_equal first, selected_name(app), "stops at the top"
  end

  def test_wheel_over_a_table_panel_moves_its_selection_without_a_click
    app = standard_app
    press(app, *where(app, "clock"))
    x, y = where(app, "codex")

    wheel(app, x, y, Mouse::BUTTON_WHEEL_DOWN)

    assert_equal 1, app.panel_state(app.dashboard.panels.find { |p| p.name == :process }).selected
  end

  def test_on_click_runs_with_the_message_and_panel
    clicks = []
    app = app_with do
      mouse :cell
      on_click { |msg, panel| clicks << [msg.x, msg.y, msg.button, panel&.name] }
      on_click { |_msg, panel| quit if panel.nil? }
      row(height: 3) { panel(:clock, resource: nil) { view { "clock" } } }
      row { panel :process }
    end
    x, y = where(app, "clock")

    assert_nil press(app, x, y)
    press(app, x, y, button: Mouse::BUTTON_RIGHT)
    wheel(app, x, y, Mouse::BUTTON_WHEEL_DOWN)
    app.update(Mouse.new(x:, y:, button: LEFT, action: Mouse::ACTION_RELEASE))
    out = press(app, 0, HEIGHT - 1)

    assert_equal [[x, y, LEFT, :clock], [x, y, Mouse::BUTTON_RIGHT, :clock], [0, HEIGHT - 1, LEFT, nil]], clicks
    assert_kind_of Bubbletea::QuitCommand, out, "a block's command runs"
  end

  def test_on_click_needs_a_block
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { on_click } }
  end

  APP = <<~RUBY
    require "r2ui"

    Fruit = Struct.new(:name, :count)
    R2UI.resource :fruit do
      source { [Fruit.new("apple", 3), Fruit.new("banana", 5)] }
      column :name
      column :count, format: :integer
    end

    R2UI.dashboard do
      mouse :cell
      on_click { |_msg, panel| state[:clicked] = panel&.name }
      row(height: 3) { panel(:clock, resource: nil) { view { "clicked: \#{state[:clicked]}" } } }
      row { panel :fruit }
    end

    R2UI.run
  RUBY

  def test_reporting_is_on_while_running_and_off_on_exit
    run = PtyHelper.run(APP, load_path: [PtyHelper::LIB], width: 60, height: 16) do |driver|
      driver.wait_for("banana")
      driver.type("\e[<0;5;2M", "\e[<0;5;2m")
      driver.wait_for("clicked: clock")
      driver.type("q")
    end

    assert run.status.success?, run.output.inspect
    assert run.tty_restored, "terminal left in raw mode"
    on = run.output.index("\e[?1002h\e[?1006h")
    off = run.output.rindex("\e[?1002l\e[?1003l\e[?1006l")
    assert on, "mouse reporting turned on: #{run.output[0, 80].inspect}"
    assert off, "mouse reporting turned off: #{run.output[-80..].inspect}"
    assert_operator off, :>, run.output.rindex("clicked: clock")
  end
end
