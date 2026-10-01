# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require "pty"
require "io/console"

BRANCHES = %w[main develop feature/billing feature/login fix/env-vars release/1.4].freeze

# Off a terminal: read a line, return the best match, raise when nothing matches.
class FilterPipeTest < Minitest::Test
  include R2UI::CLI::Testing

  def pick(input, choices = BRANCHES)
    with_shell(input:) { R2UI::CLI.filter("Branch?", choices) }
  end

  def test_returns_the_best_match_and_records_it_on_stderr
    value, shell = pick("login\n")
    assert_equal "feature/login", value
    assert_equal "✔ Branch? · feature/login\n", shell.error.string
    assert_equal "", shell.output.string
  end

  def test_fuzzy_match_skips_characters
    assert_equal "feature/billing", pick("fbil\n").first
    assert_equal "fix/env-vars", pick("fxenv\n").first
  end

  def test_case_insensitive
    assert_equal "release/1.4", pick("RELEASE\n").first
  end

  def test_prefers_an_exact_match
    assert_equal "main", pick("main\n", %w[maintenance main domain]).first
  end

  def test_prefers_contiguous_and_word_start_matches
    assert_equal "develop", pick("dev\n", %w[drop-events-v2 develop]).first
    assert_equal "feature/login", pick("log\n", %w[backlog-old feature/login]).first
  end

  def test_hash_choices_return_the_value
    value, shell = pick("us\n", { "Europe (eu-west-1)" => :eu, "US East (us-east-1)" => :us })
    assert_equal :us, value
    assert_equal "✔ Branch? · US East (us-east-1)\n", shell.error.string
  end

  def test_nothing_matches_raises
    error = assert_raises(R2UI::CLI::Error) { pick("zzz\n") }
    assert_includes error.message, "Branch?"
    assert_includes error.message, "zzz"
  end

  def test_end_of_input_raises_naming_the_question
    error = assert_raises(R2UI::CLI::Error) { pick("") }
    assert_includes error.message, "Branch?"
  end

  def test_no_match_in_a_command_exits_1
    program = R2UI::CLI::Program.build("tool") do
      run { say "checked out #{filter("Branch?", BRANCHES)}" }
    end
    assert_equal "checked out develop\n", run_cli(program, input: "devl\n").out
    result = run_cli(program, input: "nope\n")
    assert_equal 1, result.code
    assert_equal "", result.out
    assert_includes result.err, "✖"
  end

  def test_no_escape_codes_off_a_terminal
    _, shell = pick("main\n")
    refute_includes shell.error.string, "\e"
  end
end

# stdin is a terminal, stdout piped: ask the question on stderr.
class FilterTypedLineTest < Minitest::Test
  class FakeTerminal
    def initialize(*lines) = @lines = lines

    def tty? = true

    def gets = @lines.shift
  end

  def test_asks_on_stderr
    shell = R2UI::CLI::Shell.new(input: FakeTerminal.new("bill\n"), output: StringIO.new, error: StringIO.new, env: {})
    previous = R2UI::CLI.instance_variable_get(:@shell)
    R2UI::CLI.shell = shell
    assert_equal "feature/billing", R2UI::CLI.filter("Branch?", BRANCHES)
    assert_equal "Branch? ", shell.error.string
    assert_equal "", shell.output.string
  ensure
    R2UI::CLI.shell = previous
  end
end

# The inline model: a TextInput above a fuzzy-narrowed list.
class FilterModelTest < Minitest::Test
  include R2UI::CLI::Testing
  K = Bubbletea::KeyMessage

  def setup = R2UI::CLI.require_bubbles!

  def model(choices = BRANCHES, color: false, **options)
    shell = test_shell(color:)
    R2UI::CLI::Ext::Filter::Model.new(shell, "Branch?", choices, **options)
  end

  def type(model, text)
    text.each_char { |c| model, = model.update(K.new(key_type: K::KEY_RUNES, runes: [c.ord])) }
    model
  end

  def press(model, type)
    model, command = model.update(K.new(key_type: type))
    [model, command]
  end

  def plain(text) = text.gsub(/\e\[[0-9;?]*[A-Za-z]/, "")

  def list_lines(model) = plain(model.view).lines(chomp: true).drop(1)

  def test_shows_every_choice_before_typing
    lines = list_lines(model)
    assert_equal "› main", lines.first
    assert_equal BRANCHES.map { |b| b == "main" ? "› main" : "  #{b}" }, lines
  end

  def test_question_and_query_on_the_first_line
    first = plain(type(model, "feat").view).lines(chomp: true).first
    assert_match(/\A\? Branch\? .*feat/, first)
    assert_includes first, "2/6"
  end

  def test_typing_narrows_the_list
    assert_equal ["› feature/billing", "  feature/login"], list_lines(type(model, "feat"))
    assert_equal ["› feature/login"], list_lines(type(model, "flog"))
  end

  def test_best_match_first
    assert_equal "› develop", list_lines(type(model(%w[drop-events-v2 develop]), "dev")).first
  end

  def test_backspace_widens_again
    m = type(model, "flog")
    3.times { m, = press(m, K::KEY_BACKSPACE) }
    assert_equal ["› feature/billing", "  feature/login", "  fix/env-vars"], list_lines(m)
  end

  def test_matched_characters_are_highlighted
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    m = type(model(color: true), "flog")
    line = m.view.lines(chomp: true).last
    styled = ->(text) { m.shell.paint(text, :highlight) }
    refute_equal "f", styled.("f")
    assert_includes line, styled.("f")
    assert_includes line, styled.("log")
    refute_includes line, styled.("eature")
    assert_equal "› feature/login", plain(line)
  ensure
    R2UI::Compat::Gloss::Renderer.color_profile = nil
  end

  def test_down_up_and_enter_pick
    m, = press(model, K::KEY_DOWN)
    m, = press(m, K::KEY_DOWN)
    assert_equal "› feature/billing", list_lines(m)[2]
    m, = press(m, K::KEY_UP)
    m, command = press(m, K::KEY_ENTER)
    assert m.done?
    refute_nil command
    assert_equal "develop", m.value
  end

  def test_ctrl_n_and_ctrl_p_move
    m, = press(model, K::KEY_CTRL_N)
    assert_equal "› develop", list_lines(m)[1]
    m, = press(m, K::KEY_CTRL_P)
    assert_equal "› main", list_lines(m)[0]
  end

  def test_enter_picks_the_top_match_after_typing
    m = type(model, "rel")
    m, = press(m, K::KEY_ENTER)
    assert_equal "release/1.4", m.value
  end

  def test_up_down_stop_at_the_ends
    m, = press(model, K::KEY_UP)
    assert_equal "› main", list_lines(m).first
    10.times { m, = press(m, K::KEY_DOWN) }
    assert_equal "› release/1.4", list_lines(m).last
  end

  def test_no_matches_and_enter_does_nothing
    m = type(model, "zzz")
    assert_equal ["  No matches"], list_lines(m)
    m, command = press(m, K::KEY_ENTER)
    refute m.done?
    assert_nil command
  end

  def test_scrolls_past_the_limit_with_hints
    m = model((1..15).map { |i| "item-#{i}" })
    lines = list_lines(m)
    assert_equal 11, lines.size
    assert_equal "  ↓ 5 more", lines.last
    12.times { m, = press(m, K::KEY_DOWN) }
    lines = list_lines(m)
    assert_equal "  ↑ 3 more", lines.first
    assert_includes lines, "› item-13"
    assert_equal "  ↓ 2 more", lines.last
  end

  def test_hash_choices
    m = model({ "Europe" => :eu, "United States" => :us })
    m = type(m, "uni")
    m, = press(m, K::KEY_ENTER)
    assert_equal :us, m.value
    assert_equal "✔ Branch? · United States", m.view
  end

  def test_view_after_picking
    m = type(model, "bill")
    m, = press(m, K::KEY_ENTER)
    assert_equal "✔ Branch? · feature/billing", m.view
  end

  def test_ctrl_c_and_esc_interrupt
    [K::KEY_CTRL_C, K::KEY_ESC].each do |type|
      m, command = press(model, type)
      assert m.interrupted?
      refute_nil command
      assert_equal "✖ Branch?", m.view
    end
  end
end

# The inline prompt on a real pseudo-terminal, in this process.
class FilterTerminalTest < Minitest::Test
  def setup
    @master, @slave = PTY.open
    @slave.winsize = [20, 60]
    @buffer = +""
    @lock = Mutex.new
    @reader = Thread.new do
      loop do
        chunk = @master.readpartial(4096)
        @lock.synchronize { @buffer << chunk.force_encoding(Encoding::UTF_8) }
      end
    rescue IOError, Errno::EIO
      nil
    end
    @shell = R2UI::CLI::Shell.new(input: @slave, output: @slave, error: @slave, env: { "TERM" => "xterm" })
  end

  def teardown
    if @asker
      @asker.kill
      begin
        @asker.join(1)
      rescue Exception # rubocop:disable Lint/RescueException -- join re-raises the thread's Interrupt
        nil
      end
    end
    @slave.close unless @slave.closed?
    @master.close unless @master.closed?
    @reader&.kill
    @reader&.join(1)
  end

  def pick
    @asker = Thread.new do
      previous = R2UI::CLI.instance_variable_get(:@shell)
      R2UI::CLI.shell = @shell
      R2UI::CLI.filter("Branch?", BRANCHES)
    ensure
      R2UI::CLI.shell = previous
    end
    @asker.report_on_exception = false
    @asker
  end

  def plain = @lock.synchronize { @buffer.dup }.gsub(/\e\[[0-9;?]*[A-Za-z]/, "")

  def wait_for(text, timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until plain.include?(text)
      flunk "timed out waiting for #{text.inspect}; output: #{plain.inspect}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 0.01
    end
  end

  def test_types_moves_and_picks
    asker = pick
    wait_for("release/1.4")
    @master.write("feat")
    wait_for("2/6")
    @master.write("\e[B")
    wait_for("› feature/login")
    @master.write("\r")
    assert asker.join(5), "filter did not return"
    assert_equal "feature/login", asker.value
    wait_for("✔ Branch? · feature/login")
    assert @slave.echo?, "terminal left in raw mode"
  end

  def test_ctrl_c_raises_interrupt_and_restores_the_terminal
    asker = pick
    wait_for("release/1.4")
    @master.write("\x03")
    assert_raises(Interrupt) { asker.join(5) }
    wait_for("✖ Branch?")
    assert @slave.echo?, "terminal left in raw mode"
  end
end
