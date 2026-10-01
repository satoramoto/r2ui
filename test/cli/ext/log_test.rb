# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require_relative "../../../conformance/lib/vt"

class CLILogTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI

  # A plain script object that includes the helpers, as `include R2UI::CLI::Helpers` does on main.
  class Script
    include R2UI::CLI::Helpers

    def go = warn("from a script")
  end

  # Lipgloss picks its colour profile from the process's stdout; pin one for colour tests.
  def with_ansi
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    yield
  ensure
    R2UI::Compat::Gloss::Renderer.color_profile = nil
  end

  def plain(text) = text.gsub(/\e\[[\d;]*m/, "")

  def screen_text(out)
    vt = Conformance::VT.new(cols: 80, rows: 20)
    vt.feed(out)
    vt.lines.map(&:rstrip).reject(&:empty?)
  end

  # ---- plain (pipe) output ----

  def test_each_level_prints_one_line_with_its_symbol
    _, shell = with_shell do
      CLI.info("Using node 20")
      CLI.success("Installed 42 packages")
      CLI.warn("3 deprecated packages")
      CLI.error("Build failed")
    end
    assert_equal "ℹ Using node 20\n✔ Installed 42 packages\n", shell.output.string
    assert_equal "⚠ 3 deprecated packages\n✖ Build failed\n", shell.error.string
  end

  def test_plain_output_has_no_escape_codes
    _, shell = with_shell do
      %i[info success warn error].each { |level| CLI.public_send(level, "x") }
    end
    refute_includes shell.output.string + shell.error.string, "\e"
  end

  def test_helpers_return_nil
    with_shell do
      assert_nil CLI.info("a")
      assert_nil CLI.success("b")
      assert_nil CLI.warn("c")
      assert_nil CLI.error("d")
      assert_nil CLI.debug("e")
    end
  end

  def test_multi_line_messages_indent_under_the_first
    _, shell = with_shell do
      CLI.warn("Peer dependency missing\nreact@18 is required\n")
      CLI.info("one\n\ntwo")
    end
    assert_equal "⚠ Peer dependency missing\n  react@18 is required\n", shell.error.string
    assert_equal "ℹ one\n\n  two\n", shell.output.string
  end

  # ---- debug ----

  def test_debug_is_silent_by_default
    _, shell = with_shell { CLI.debug("resolving") }
    assert_equal "", shell.output.string
    assert_equal "", shell.error.string
  end

  def test_debug_prints_to_stderr_with_r2ui_debug
    _, shell = with_shell(env: { "R2UI_DEBUG" => "1" }) { CLI.debug("resolving\ncache hit") }
    assert_equal "", shell.output.string
    assert_equal "• resolving\n  cache hit\n", shell.error.string
  end

  def test_debug_prints_with_verbose_in_a_command
    tool = CLI::Program.build("tool") do
      flag :verbose, short: "v"
      run { debug "resolving" }
    end
    quiet = run_cli(tool)
    assert_equal 0, quiet.code
    assert_equal "", quiet.err

    loud = run_cli(tool, "-v")
    assert_equal 0, loud.code
    assert_equal "• resolving\n", loud.err
    assert_equal "", loud.out
  end

  def test_debug_in_a_command_without_a_verbose_option
    tool = CLI::Program.build("tool") { run { debug "x" } }
    assert_equal "", run_cli(tool).err
    assert_equal "• x\n", run_cli(tool, env: { "R2UI_DEBUG" => "1" }).err
  end

  # ---- in commands and scripts ----

  def test_levels_inside_a_command
    tool = CLI::Program.build("tool") do
      run do
        info "Deploying"
        warn "No healthcheck configured"
        success "Deployed"
      end
    end
    result = run_cli(tool)
    assert_equal 0, result.code
    assert_equal "ℹ Deploying\n✔ Deployed\n", result.out
    assert_equal "⚠ No healthcheck configured\n", result.err
  end

  def test_warn_replaces_kernel_warn_in_a_command
    tool = CLI::Program.build("tool") { run { warn "careful", "really" } }
    result = run_cli(tool)
    assert_equal "⚠ careful\n  really\n", result.err
  end

  def test_warn_replaces_kernel_warn_in_a_script
    _, shell = with_shell { Script.new.go }
    assert_equal "⚠ from a script\n", shell.error.string
  end

  def test_warn_with_no_message_prints_nothing
    _, shell = with_shell { CLI.warn }
    assert_equal "", shell.error.string
  end

  # ---- on a terminal ----

  def test_terminal_colours_the_symbol_by_level
    _, shell = with_ansi do
      with_shell(tty: true, color: true) do
        CLI.info("i")
        CLI.success("s")
        CLI.warn("w")
        CLI.error("e")
      end
    end
    out = shell.output.string
    err = shell.error.string
    assert_includes out, "\e["
    assert_includes err, "\e["
    assert_equal "ℹ i\n✔ s\n", plain(out)
    assert_equal "⚠ w\n✖ e\n", plain(err)
    # The level colours differ from each other.
    codes = [out.lines[0], out.lines[1], err.lines[0], err.lines[1]].map { |l| l[/\e\[[\d;]*m/] }
    assert_equal 4, codes.uniq.size
  end

  def test_terminal_debug_is_muted
    _, shell = with_ansi { with_shell(tty: true, color: true, env: { "R2UI_DEBUG" => "1" }) { CLI.debug("d") } }
    assert_includes shell.error.string, "\e["
    assert_equal "• d\n", plain(shell.error.string)
  end

  def test_inside_a_live_region_lines_print_above_it
    _, shell = with_shell(tty: true) do
      CLI.tasks do
        CLI.step("Building") { CLI.info("compiled 3 files") }
        CLI.step("Uploading") { CLI.success("uploaded") }
      end
    end
    lines = screen_text(shell.output.string)
    assert_equal "ℹ compiled 3 files", lines[0]
    assert_equal "✔ uploaded", lines[1]
    assert_match(/\A✔ Building /, lines[2])
    assert_match(/\A✔ Uploading /, lines[3])
    assert_equal 4, lines.size
  end
end
