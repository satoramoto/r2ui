# frozen_string_literal: true

require "test_helper"
require_relative "../compat/bubbletea/pty_helper"

# s15-paste: bracketed paste. `paste` turns it on; a paste reaches the search prompt or a focused
# component as text, otherwise `on_paste`; it is turned off on exit.
#
# Decisions the tests pin (change them here and in lib/r2ui/ext/paste.rb together):
# - `on_paste` alone also turns bracketed paste on (a handler with no paste would never run).
# - With no prompt, no focused component and no `on_paste`, a paste is dropped: it never acts as
#   key bindings ("q" in a paste does not quit).
# - In the search prompt, newlines and other control characters in a paste are dropped, so a paste
#   never submits or cancels the prompt.
# - A focused component gets the paste as one message (the paste KeyMessage, all runes at once).
class PasteTest < Minitest::Test
  InputItem = Data.define(:name)

  # A Bubbletea-style model that records every message it is sent.
  class Recorder
    attr_reader :messages

    def initialize = @messages = []
    def focus = nil
    def blur = nil
    def view = "recorder"

    def update(message)
      @messages << message
      [self, nil]
    end
  end

  def setup
    R2UI.reset!
    Fixtures.define_processes
    unless R2UI::Extensions[:test_paste_input]
      R2UI.extension(:test_paste_input) do
        dsl(:panel) { def recorder(name) = item(InputItem.new(name)) }
        component(InputItem, focusable: true) { |_item| Recorder.new }
      end
    end
  end

  def teardown = R2UI::Extensions.remove(:test_paste_input)

  # What the terminal sends for a paste, decoded by the engine's input decoder.
  def paste(text)
    event = R2UI::Compat::Tea::Input.parse_all("\e[200~#{text}\e[201~").fetch(0)
    Bubbletea.parse_event(event)
  end

  def build(&)
    R2UI.dashboard(&)
    R2UI::App.new(R2UI.registry)
  end

  def quit?(command) = command.is_a?(Bubbletea::QuitCommand)

  def test_paste_turns_on_bracketed_paste
    app = build { paste; row { panel :process } }
    assert_equal true, app.program_options[:bracketed_paste]
  end

  def test_bracketed_paste_is_off_without_paste
    app = build { row { panel :process } }
    refute app.program_options[:bracketed_paste]
  end

  def test_on_paste_alone_turns_on_bracketed_paste
    app = build { on_paste { |_text| nil }; row { panel :process } }
    assert_equal true, app.program_options[:bracketed_paste]
  end

  def test_paste_reaches_the_search_prompt_as_text
    app = build { paste; row { panel :process } }

    app.press("/")
    app.update(paste("claude"))

    assert_equal "claude", app.panel_state(app.focus).search
    assert_match(%r{/claude▏}, app.frame(80, 10).plain_lines.join("\n"))
  end

  def test_paste_is_appended_to_what_was_typed_in_the_prompt
    app = build { paste; row { panel :process } }

    app.press("/", "c")
    app.update(paste("laude"))

    assert_equal "claude", app.panel_state(app.focus).search
  end

  def test_paste_into_search_does_not_trigger_bindings
    app = build { paste; row { panel :process } }

    app.press("/")
    _, command = app.update(paste("qzjk"))

    refute quit?(command), "q inside a paste is text"
    assert_equal "qzjk", app.panel_state(app.focus).search
  end

  def test_paste_into_search_drops_newlines_and_keeps_the_prompt_open
    app = build { paste; row { panel :process } }

    app.press("/")
    app.update(paste("no\nde\n"))
    app.press("x")

    assert_equal "nodex", app.panel_state(app.focus).search, "the prompt is still open after the paste"
  end

  def test_on_paste_gets_the_text_when_no_prompt_is_open
    app = build do
      paste
      on_paste { |text| state[:pasted] = text }
      row { panel :process }
    end

    app.update(paste("hello q world\nsecond line"))

    assert_equal "hello q world\nsecond line", app.state[:pasted]
  end

  def test_on_paste_runs_on_a_context_and_may_return_a_command
    app = build do
      paste
      on_paste { |text| flash "got #{text.size}"; quit }
      row { panel :process }
    end

    _, command = app.update(paste("abcd"))

    assert quit?(command)
    assert_match(/got 4/, app.frame(60, 8).plain_lines.join("\n"))
  end

  def test_on_paste_does_not_get_a_paste_the_search_prompt_took
    app = build do
      paste
      on_paste { |text| state[:pasted] = text }
      row { panel :process }
    end

    app.press("/")
    app.update(paste("claude"))

    assert_nil app.state[:pasted]
    assert_equal "claude", app.panel_state(app.focus).search
  end

  def test_on_paste_does_not_see_typed_keys
    app = build do
      paste
      on_paste { |text| state[:pasted] = text }
      row { panel :process }
    end

    app.press("x", "[", "y")

    assert_nil app.state[:pasted]
  end

  def test_a_paste_with_nowhere_to_go_is_dropped_not_run_as_keys
    app = build { paste; row { panel :process } }

    _, command = app.update(paste("qzjjs"))

    refute quit?(command)
    assert_equal 0, app.panel_state(app.focus).selected, "j in a paste does not move the selection"
  end

  def test_a_single_typed_bracket_is_not_a_paste
    app = build do
      paste
      on_paste { |text| state[:pasted] = text }
      row { panel :process }
    end

    app.press("[")
    app.press("x")

    assert_nil app.state[:pasted]
  end

  def test_paste_reaches_a_focused_component_as_one_message
    app = build do
      paste
      on_paste { |text| state[:pasted] = text }
      row { panel(:form, resource: nil) { recorder :name } }
      row { panel :process }
    end
    app.focus = app.dashboard.panels.first
    app.init
    recorder = app.component(:name)
    before = recorder.messages.size

    app.update(paste("hello q world"))

    received = recorder.messages.drop(before)
    assert_equal 1, received.size, "one message for the whole paste, not one per character"
    assert_kind_of Bubbletea::KeyMessage, received.first
    assert_equal "hello q world", received.first.char
    assert_nil app.state[:pasted], "a focused component takes the paste before on_paste"
  ensure
    app&.stop
  end

  def test_paste_goes_to_on_paste_once_the_component_loses_focus
    app = build do
      paste
      on_paste { |text| state[:pasted] = text }
      row { panel(:form, resource: nil) { recorder :name } }
      row { panel :process }
    end
    app.focus = app.dashboard.panels.first
    app.init
    app.press(:tab)

    app.update(paste("elsewhere"))

    assert_equal "elsewhere", app.state[:pasted]
    refute(app.component(:name).messages.any? { |m| m.respond_to?(:char) && m.char == "elsewhere" })
  ensure
    app&.stop
  end

  APP = <<~RUBY
    require "r2ui"

    Fruit = Struct.new(:name, :count)
    R2UI.resource :fruit do
      source { [Fruit.new("apple", 3), Fruit.new("banana", 5)] }
      column :name
      column :count, format: :integer
      filter :name
    end

    R2UI.dashboard do
      paste
      on_paste { |text| state[:pasted] = text }
      row { panel :fruit }
      row(height: 3) { panel(:note, resource: nil) { view { "pasted=\#{state[:pasted].inspect}" } } }
    end

    R2UI.run
  RUBY

  def test_paste_is_on_while_running_and_off_on_exit
    run = PtyHelper.run(APP, load_path: [PtyHelper::LIB], width: 60, height: 16) do |driver|
      driver.wait_for("banana")
      driver.type("\e[200~hello\e[201~")
      driver.wait_for('pasted="hello"')
      driver.type("q")
    end

    assert run.status.success?, run.output.inspect
    assert run.tty_restored
    assert_includes run.output, "\e[?2004h", "bracketed paste turned on"
    assert_includes run.output, "\e[?2004l", "bracketed paste turned off on exit"
    assert_operator run.output.rindex("\e[?2004l"), :>, run.output.index("\e[?2004h")
  end
end
