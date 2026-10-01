# frozen_string_literal: true

require_relative "helper"
require_relative "pty_helper"

# The terminal is restored however the program ends: quit, an exception in the model, or a signal.
class BubbleteaExitPathsTest < Minitest::Test
  APP = <<~RUBY
    class App
      include Bubbletea::Model

      def update(message)
        case message
        when Bubbletea::KeyMessage
          raise "boom" if message.to_s == "x"
          return [self, Bubbletea.quit] if message.to_s == "q"

          @last = message.to_s
        when Bubbletea::MouseMessage
          @last = "mouse \#{message.x},\#{message.y} b\#{message.button} a\#{message.action}"
        when Bubbletea::FocusMessage then @last = "focus"
        when Bubbletea::BlurMessage then @last = "blur"
        end
        [self, nil]
      end

      def view = "ready last=\#{@last}"
    end

    Bubbletea.run(App.new, **OPTIONS)
  RUBY

  ALL_MODES = { alt_screen: true, mouse_all_motion: true, bracketed_paste: true, report_focus: true }.freeze
  RESTORE = "\e[?1002l\e[?1003l\e[?1006l\e[?2004l\e[?1004l\e[?1049l\e[?25h"

  def app(options) = "#{PtyHelper::OURS}\nOPTIONS = #{options.inspect}\n#{APP}"

  def run_app(options = ALL_MODES, &)
    PtyHelper.run(app(options), load_path: [PtyHelper::LIB], &)
  end

  def test_quit_restores_everything
    run = run_app { |d| d.wait_for("ready"); d.type("q") }
    assert run.status.success?
    assert run.tty_restored
    assert_includes run.output, "\e[?1003h\e[?1006h\e[?2004h\e[?1004h"
    assert run.output.end_with?(RESTORE), run.output.inspect
  end

  def test_exception_in_update_restores_everything
    run = run_app { |d| d.wait_for("ready"); d.type("x") }
    refute run.status.success?
    assert run.tty_restored
    assert_includes run.output, RESTORE
    assert_includes run.output, "boom"
  end

  def test_sigterm_restores_everything
    run = run_app { |d| d.wait_for("ready"); d.signal("TERM") }
    refute run.status.success?
    assert run.tty_restored
    assert_includes run.output, RESTORE
  end

  def test_sighup_restores_inline_mode
    run = run_app({}) { |d| d.wait_for("ready"); d.signal("HUP") }
    assert run.tty_restored
    assert run.output.end_with?("\r\n\e[?25h"), run.output.inspect
  end

  def test_mouse_focus_and_paste_reach_the_model
    run = run_app do |d|
      d.wait_for("ready")
      d.type("\e[<0;5;3M")
      d.wait_for("mouse 4,2 b0 a0")
      d.type("\e[<35;10;7M")
      d.wait_for("mouse 9,6 b3 a2")
      d.type("\e[<64;1;1M")
      d.wait_for("mouse 0,0 b4 a0")
      d.type("\e[I")
      d.wait_for("last=focus")
      d.type("\e[O")
      d.wait_for("last=blur")
      d.type("\e[200~hi there\e[201~")
      d.wait_for("last=[hi there]")
      d.type("\e[15~")
      d.wait_for("last=f5")
      d.type("\e[Z")
      d.wait_for("last=shift+tab")
      d.type("\eb")
      d.wait_for("last=alt+b")
      d.type("\x17")
      d.wait_for("last=ctrl+w")
      d.type("q")
    end
    assert run.status.success?, run.output.inspect
    assert run.tty_restored
  end
end
