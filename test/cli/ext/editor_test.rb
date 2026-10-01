# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require "shellwords"
require "tmpdir"
require "rbconfig"
require_relative "../../../conformance/lib/vt"

class EditorTest < Minitest::Test
  include R2UI::CLI::Testing
  CLI = R2UI::CLI

  # A pretend editor: records the file it was given (and its contents on open), then edits it.
  EDITOR_SCRIPT = <<~RUBY
    log, mode, path = ARGV
    File.write(log, path + "\\n" + File.read(path))
    case mode
    when "upcase" then File.write(path, File.read(path).upcase)
    when "replace" then File.write(path, "replaced\\n")
    when "fail" then exit 3
    end
  RUBY

  def setup
    @dir = Dir.mktmpdir("editor-test")
    @script = File.join(@dir, "fake_editor.rb")
    @log = File.join(@dir, "log")
    File.write(@script, EDITOR_SCRIPT)
  end

  def teardown = FileUtils.remove_entry(@dir)

  def editor(mode = "upcase") = [RbConfig.ruby, @script, @log, mode].map { |part| Shellwords.escape(part) }.join(" ")

  def edit_on_terminal(*args, env: { "EDITOR" => editor }, **options)
    with_shell(tty: true, interactive: true, env:) { CLI.edit(*args, **options) }
  end

  def opened_path = File.read(@log).lines.first.chomp

  def opened_text = File.read(@log).lines.drop(1).join

  def screen_text(out)
    vt = Conformance::VT.new(cols: 80, rows: 10)
    vt.feed(out.gsub("\n", "\r\n"))
    vt.lines.map(&:rstrip).reject(&:empty?)
  end

  # ---- on a terminal ----

  def test_returns_what_the_editor_saved
    value, = edit_on_terminal("# Release notes\n")
    assert_equal "# RELEASE NOTES\n", value
    assert_equal "# Release notes\n", opened_text
  end

  def test_starts_empty_by_default
    value, = edit_on_terminal(env: { "EDITOR" => editor("replace") })
    assert_equal "", opened_text
    assert_equal "replaced\n", value
  end

  def test_extension_defaults_to_markdown_and_can_be_changed
    edit_on_terminal("x")
    assert_equal ".md", File.extname(opened_path)
    edit_on_terminal("x", ext: ".yml")
    assert_equal ".yml", File.extname(opened_path)
  end

  def test_temp_file_is_removed
    edit_on_terminal("x")
    refute File.exist?(opened_path), "temp file left behind"
  end

  def test_visual_wins_over_editor
    value, = edit_on_terminal("x", env: { "VISUAL" => editor("replace"), "EDITOR" => "false" })
    assert_equal "replaced\n", value
  end

  def test_defaults_to_vi
    bin = File.join(@dir, "bin")
    Dir.mkdir(bin)
    vi = File.join(bin, "vi")
    File.write(vi, "#!/bin/sh\nexec #{editor("replace")} \"$@\"\n")
    File.chmod(0o755, vi)
    path = ENV.fetch("PATH", nil)
    ENV["PATH"] = "#{bin}#{File::PATH_SEPARATOR}#{path}"
    value, = edit_on_terminal("x", env: {})
    assert_equal "replaced\n", value
  ensure
    ENV["PATH"] = path
  end

  def test_editor_failure_is_an_error_and_removes_the_file
    error = assert_raises(CLI::Error) { edit_on_terminal("x", env: { "EDITOR" => editor("fail") }) }
    assert_includes error.message, "exited with status 3"
    refute File.exist?(opened_path), "temp file left behind"
  end

  def test_missing_editor_is_an_error
    error = assert_raises(CLI::Error) { edit_on_terminal("x", env: { "EDITOR" => "no-such-editor-r2ui" }) }
    assert_includes error.message, "no-such-editor-r2ui"
  end

  def test_waiting_hint_is_erased_when_the_editor_closes
    _, shell = edit_on_terminal("x")
    assert_includes shell.output.string, "Waiting for your editor"
    assert_equal [], screen_text(shell.output.string)
  end

  def test_works_in_a_command
    env = { "EDITOR" => editor }
    program = CLI::Program.build("tool") { run { say(edit("hello")) } }
    shell = test_shell(tty: true, interactive: true, env:)
    assert_equal 0, program.call([], shell:)
    assert_equal ["HELLO"], screen_text(shell.output.string)
  end

  # ---- off a terminal ----

  def test_off_a_terminal_raises_without_running_the_editor
    error = assert_raises(CLI::Error) { with_shell(env: { "EDITOR" => editor }) { CLI.edit("x") } }
    assert_includes error.message, "needs a terminal"
    refute File.exist?(@log), "editor ran off a terminal"
  end

  def test_off_a_terminal_a_command_exits_1
    program = CLI::Program.build("tool") { run { say(edit("x")) } }
    result = run_cli(program, env: { "EDITOR" => editor })
    assert_equal 1, result.code
    assert_equal "", result.out
    assert_includes result.err, "✖"
    assert_includes result.err, "needs a terminal"
    refute_includes result.err, "\e"
  end
end
