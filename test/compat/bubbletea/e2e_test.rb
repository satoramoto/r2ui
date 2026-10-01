# frozen_string_literal: true

require_relative "helper"
require_relative "pty_helper"

# End to end: whole programs on a pty, ours against the real gem's byte stream when it's installed.
class BubbleteaE2ETest < Minitest::Test
  COUNTER = <<~RUBY
    class Counter
      include Bubbletea::Model

      def initialize = @count = 0

      def update(message)
        return [self, nil] unless message.is_a?(Bubbletea::KeyMessage)

        case message.to_s
        when "q", "ctrl+c" then [self, Bubbletea.quit]
        when "up", "k" then @count += 1; [self, nil]
        when "down", "j" then @count -= 1; [self, nil]
        else [self, nil]
        end
      end

      def view = "Count: \#{@count}\\n\\nup/down to change, q to quit"
    end

    Bubbletea.run(Counter.new, **OPTIONS)
  RUBY

  TEXT_INPUT = <<~RUBY
    require "bubbles"

    class Form
      include Bubbletea::Model

      def initialize
        @input = Bubbles::TextInput.new
        @input.placeholder = "your name"
        @input.focus
        @input.cursor.set_mode(Bubbles::Cursor::MODE_STATIC)
      end

      def update(message)
        return [self, Bubbletea.quit] if message.is_a?(Bubbletea::KeyMessage) && %w[ctrl+c enter].include?(message.to_s)

        @input, command = @input.update(message)
        [self, command]
      end

      def view = "Name?\\n\#{@input.view}\\n(enter to finish)"
    end

    Bubbletea.run(Form.new)
  RUBY

  SPINNER = <<~RUBY
    require "bubbles"

    class Loading
      include Bubbletea::Model

      def initialize = @spinner = Bubbles::Spinner.new

      def init = [self, @spinner.tick]

      def update(message)
        return [self, Bubbletea.quit] if message.is_a?(Bubbletea::KeyMessage)

        @spinner, command = @spinner.update(message)
        [self, command]
      end

      def view = "\#{@spinner.view} loading"
    end

    Bubbletea.run(Loading.new)
  RUBY

  def counter(prelude, options = {})
    "#{prelude}\nOPTIONS = #{options.inspect}\n#{COUNTER}"
  end

  def drive_counter(driver)
    driver.wait_for("Count: 0")
    driver.type("k", "k", "\e[A", "j", "\e[B", "k", "x", "q")
  end

  def ours(code, **, &)
    PtyHelper.run(code, load_path: [PtyHelper::LIB], **, &)
  end

  def real(code, **, &)
    skip "real bubbletea 0.1.4 not installed" unless PtyHelper.real_gem?
    PtyHelper.run(code, **, &)
  end

  def assert_clean_exit(run)
    assert run.status.success?, run.output.inspect
    assert run.tty_restored, "terminal left in raw mode"
  end

  def test_counter_inline
    run = ours(counter(PtyHelper::OURS)) { drive_counter(_1) }
    assert_clean_exit(run)
    assert_includes run.output, "Count: 2"
    assert run.output.start_with?("\e[?25l"), run.output.inspect
    assert run.output.end_with?("\r\n\e[?25h"), run.output.inspect
  end

  def test_counter_inline_matches_real_gem
    want = real(counter(PtyHelper::REAL)) { drive_counter(_1) }
    got = ours(counter(PtyHelper::OURS)) { drive_counter(_1) }
    assert_clean_exit(want)
    assert_clean_exit(got)
    assert_equal want.output, got.output
  end

  def test_counter_alt_screen_matches_real_gem
    want = real(counter(PtyHelper::REAL, alt_screen: true)) { drive_counter(_1) }
    got = ours(counter(PtyHelper::OURS, alt_screen: true)) { drive_counter(_1) }
    assert_clean_exit(got)
    assert_includes got.output, "\e[?1049h"
    assert got.output.end_with?("\e[?1049l\e[?25h"), got.output.inspect
    assert_equal want.output, got.output
  end

  def drive_text_input(driver)
    driver.wait_for("(enter to finish)")
    driver.type("h", "é", "l", "l", "o", " ", "世", "界", "\x7f", "\e[D", "\e[D", "!", "\x01", ">", "\r")
  end

  def test_bubbles_text_input_matches_real_gem
    skip "real bubbles/lipgloss not installed" unless PtyHelper.real_gem?("bubbles", "0.1.1") && PtyHelper.real_gem?("lipgloss", "0.2.2")

    want = real(PtyHelper::REAL + TEXT_INPUT) { drive_text_input(_1) }
    got = PtyHelper.run(PtyHelper::OURS_WITH_REAL_LIPGLOSS + TEXT_INPUT, load_path: [PtyHelper::SHIM]) { drive_text_input(_1) }
    assert_clean_exit(got)
    assert_equal want.output, got.output
  end

  # Spinner frames are timer-driven, so the streams can't match byte for byte; every frame we draw
  # must be one the real gem draws, and the spinner must actually advance.
  def test_bubbles_spinner_animates_like_real_gem
    skip "real bubbles/lipgloss not installed" unless PtyHelper.real_gem?("bubbles", "0.1.1") && PtyHelper.real_gem?("lipgloss", "0.2.2")

    drive = ->(driver) { driver.wait_for("loading"); driver.pause(0.6); driver.type("q") }
    want = real(PtyHelper::REAL + SPINNER, &drive)
    got = PtyHelper.run(PtyHelper::OURS_WITH_REAL_LIPGLOSS + SPINNER, load_path: [PtyHelper::SHIM], &drive)
    assert_clean_exit(got)
    frames = ->(run) { run.output.scan(/\r([^\r\e]*) loading\e\[K/n).flatten.uniq }
    assert_operator frames.(got).size, :>=, 3, got.output.inspect
    assert_empty frames.(got) - frames.(want)
  end
end
