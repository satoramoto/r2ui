# frozen_string_literal: true

require "test_helper"
require_relative "../compat/bubbletea/pty_helper"

# s12-window-title: `window_title` sets the terminal title at init and whenever its value changes;
# `set_window_title(text)` sets it now. Bubbletea writes it as OSC 2 ("\e]2;<title>\a").
class WindowTitleTest < Minitest::Test
  # A message that changes nothing, to drive updates.
  class Bump < Bubbletea::Message; end

  def setup = R2UI.reset!

  def commands(command)
    case command
    when nil then []
    when Bubbletea::BatchCommand then command.commands
    else [command]
    end
  end

  def titles(command) = commands(command).grep(Bubbletea::SetWindowTitleCommand).map(&:title)

  def app_for(&definition)
    R2UI.dashboard(&definition)
    R2UI::App.new(R2UI.registry)
  end

  def test_static_title_is_set_at_init_only
    app = app_for do
      window_title "Agents"
      row { panel(:p, resource: nil) { view { "x" } } }
    end

    _, command = app.init
    assert_equal ["Agents"], titles(command)

    _, command = app.update(Bump.new)
    assert_empty titles(command)
  ensure
    app&.stop
  end

  def test_block_title_is_set_at_init_and_again_only_when_it_changes
    app = app_for do
      window_title { "#{state[:count].to_i} deploys" }
      row { panel(:p, resource: nil) { view { "x" } } }
    end
    bump = Bump

    _, command = app.init
    assert_equal ["0 deploys"], titles(command)

    _, command = app.update(bump.new)
    assert_empty titles(command), "unchanged title is not re-sent"

    app.state[:count] = 2
    _, command = app.update(bump.new)
    assert_equal ["2 deploys"], titles(command)

    _, command = app.update(bump.new)
    assert_empty titles(command)
  ensure
    app&.stop
  end

  def test_set_window_title_helper_sets_it_now
    R2UI.extension(:window_title_test_key) do
      on(Bump) { set_window_title("now") }
    end
    app = app_for { row { panel(:p, resource: nil) { view { "x" } } } }
    app.init

    _, command = app.update(Bump.new)

    assert_equal ["now"], titles(command)
  ensure
    app&.stop
    R2UI::Extensions.remove(:window_title_test_key)
  end

  def test_needs_exactly_one_of_text_or_block
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { window_title } }
    assert_raises(ArgumentError) { R2UI.dashboard(:bad2) { window_title("a") { "b" } } }
  end

  APP = <<~RUBY
    require "r2ui"

    R2UI.dashboard do
      window_title { "ticks \#{state[:ticks].to_i >= 2 ? 'many' : 'few'}" }
      every(0.05) { state[:ticks] = state[:ticks].to_i + 1 }
      row { panel(:clock, resource: nil) { view { state[:ticks].to_i >= 2 ? "ticking" : "waiting" } } }
    end

    R2UI.run
  RUBY

  def test_writes_osc_2_on_a_real_terminal
    run = PtyHelper.run(APP, load_path: [PtyHelper::LIB], width: 40, height: 8) do |driver|
      driver.wait_for("ticking")
      driver.type("q")
    end

    assert run.status.success?, run.output.inspect
    assert_includes run.output, "\e]2;ticks few\a"
    assert_includes run.output, "\e]2;ticks many\a"
    assert_equal 1, run.output.scan("\e]2;ticks many\a").size, "title re-sent although unchanged"
  end
end
