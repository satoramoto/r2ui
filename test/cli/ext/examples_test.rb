# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"

# c29-examples: `example "cmd", "what it does"` adds an "Examples" section to --help.
class CLIExamplesTest < Minitest::Test
  include R2UI::CLI::Testing

  MUTED = "\e[2m"
  ACCENT = "\e[36m"

  def teardown
    R2UI::Compat::Gloss::Renderer.color_profile = nil
  end

  def tool
    @tool ||= R2UI.cli "deployer" do
      summary "Ship apps to the fleet"
      example "deployer status", "Show the fleet"

      command :deploy, "Deploy an app" do
        argument :app, desc: "App to deploy"
        option :env, short: "e", default: "staging", desc: "Target"
        example "deployer deploy api -e production", "Deploy api to production"
        example "deployer deploy web"
        run { say "deployed" }
      end

      command :status, "Show the fleet" do
        run { say "ok" }
      end

      command :db, "Database tasks" do
        example "deployer db migrate", "Run pending migrations"
        command(:migrate, "Run migrations") { run { say "migrated" } }
      end
    end
  end

  def help_for(*argv, **shell)
    result = run_cli(tool, *argv, **shell)
    assert_equal 0, result.code, "stderr: #{result.err}"
    assert_empty result.err
    result.out
  end

  def examples_section(out) = out[/^Examples\n(?:  .*\n)+/]

  def test_examples_section_off_a_terminal
    out = help_for("deploy", "--help")
    assert_equal <<~TEXT, examples_section(out)
      Examples
        # Deploy api to production
        deployer deploy api -e production
        deployer deploy web
    TEXT
    refute_includes out, "\e"
  end

  def test_section_comes_after_options
    out = help_for("deploy", "--help")
    assert_operator out.index("Options"), :<, out.index("Examples")
    assert out.end_with?("deployer deploy web\n"), out
  end

  def test_each_command_shows_only_its_own_examples
    root = help_for("--help")
    assert_includes root, "  # Show the fleet\n  deployer status\n"
    refute_includes root, "deployer deploy api"

    db = help_for("db", "--help")
    assert_includes db, "  # Run pending migrations\n  deployer db migrate\n"
    refute_includes db, "deployer status"
    assert_operator db.index("Examples"), :<, db.index("Run 'deployer db <command> --help'")
  end

  def test_no_section_without_examples
    out = help_for("status", "--help")
    refute_includes out, "Examples"
    refute_includes help_for("db", "migrate", "--help"), "Examples"
  end

  def test_help_command_shows_them_too
    assert_equal help_for("deploy", "--help"), help_for("help", "deploy")
  end

  def test_comment_muted_and_command_in_accent_on_a_terminal
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    out = help_for("deploy", "--help", tty: true, color: true)
    lines = out.lines(chomp: true)
    heading = lines.index { |l| l.include?("Examples") }
    refute_nil heading, out
    comment, command, bare = lines[heading + 1, 3]
    assert_includes comment, "#{MUTED}# Deploy api to production"
    assert_includes command, "#{ACCENT}deployer deploy api -e production"
    assert_includes bare, "#{ACCENT}deployer deploy web"
    assert command.start_with?("  "), command.inspect
    assert_equal "  # Deploy api to production", comment.gsub(/\e\[[\d;]*m/, "")
  end

  def test_multi_line_comment_keeps_every_line_a_comment
    program = R2UI.cli("tool") do
      example "tool --all", "Build everything,\nthen ship it"
      run {}
    end
    out = run_cli(program, "--help").out
    assert_includes out, "Examples\n  # Build everything,\n  # then ship it\n  tool --all\n"
  end

  def test_an_example_needs_a_command
    assert_raises(ArgumentError) { R2UI.cli("tool") { example "" } }
    assert_raises(ArgumentError) { R2UI.cli("tool") { example nil } }
  end
end
