# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"

# The generated --help, as a user of the tool reads it.
class CLIHelpTest < Minitest::Test
  include R2UI::CLI::Testing

  def teardown
    R2UI::Compat::Gloss::Renderer.color_profile = nil
    R2UI::CLI::Extensions.remove(:help_test_notes)
  end

  def tool
    @tool ||= R2UI.cli "deployer" do
      summary "Ship apps to the fleet"
      flag :verbose, short: "v", desc: "Say more"
      option :debug_level, :integer, hidden: true

      command :deploy, "Deploy an app" do
        description "Deploy an app to the fleet"
        aliases :d
        argument :app, desc: "App to deploy"
        argument :sha, default: "HEAD", desc: "Commit to deploy"
        option :env, short: "e", default: "staging", in: %w[staging production], desc: "Target environment"
        option :token, required: true, desc: "API token"
        option :tag, many: true, desc: "Tags"
        flag :force, desc: "Skip the checks"
        flag :checks, default: true, desc: "Run checks"
        run { say "deployed" }
      end

      command :db, "Database tasks" do
        command(:migrate, "Run migrations") { run { say "migrated" } }
      end

      command :secret, "Hidden thing", hidden: true do
        run { say "secret" }
      end
    end
  end

  def help_for(*argv, **shell)
    result = run_cli(tool, *argv, **shell)
    assert_equal 0, result.code, "stderr: #{result.err}"
    assert_empty result.err
    result.out
  end

  def test_long_and_short_help_flags_print_the_same_help
    assert_equal help_for("--help"), help_for("-h")
  end

  def test_root_help_sections
    out = help_for("--help")
    assert out.start_with?("Ship apps to the fleet\n\n")
    assert_includes out, "Usage\n  deployer <command> [options]"
    assert_includes out, "Commands\n"
    assert_match(/^  deploy, d +Deploy an app$/, out)
    assert_match(/^  db +Database tasks$/, out)
    assert_includes out, "Options\n"
    assert_match(/^  -v, --verbose +Say more$/, out)
    assert_match(/^  -h, --help +Show help$/, out)
    assert_includes out, "Run 'deployer <command> --help' for more about a command."
  end

  def test_help_command_shows_a_subcommands_help
    assert_equal help_for("deploy", "--help"), help_for("help", "deploy")
  end

  def test_subcommand_help_sections
    out = help_for("deploy", "--help")
    assert out.start_with?("Deploy an app to the fleet\n\n")
    assert_includes out, "Usage\n  deployer deploy <app> [sha] [options]"
    assert_includes out, "Arguments\n"
    assert_match(/^  app +App to deploy$/, out)
    assert_match(/^  sha +Commit to deploy \(default: HEAD\)$/, out)
    refute_includes out, "Commands\n"
    refute_includes out, "for more about a command"
  end

  def test_subcommand_help_works_without_its_required_input
    out = help_for("deploy", "-h")
    assert_includes out, "Usage\n  deployer deploy"
  end

  def test_help_via_alias
    assert_equal help_for("deploy", "--help"), help_for("d", "--help")
  end

  def test_options_show_choices_defaults_and_required
    out = help_for("deploy", "--help")
    assert_match(/^  -e, --env <env> +Target environment \(staging, production; default: staging\)$/, out)
    assert_match(/^      --token <token> +API token \(required\)$/, out)
    assert_match(/^      --tag <tag>\.\.\. +Tags$/, out)
  end

  def test_flags_show_no_prefix_only_when_on_by_default
    out = help_for("deploy", "--help")
    assert_match(/^      --force +Skip the checks$/, out)
    assert_match(/^      --\[no-\]checks +Run checks \(default: true\)$/, out)
  end

  def test_inherited_options_are_listed_on_subcommands
    assert_match(/^  -v, --verbose +Say more$/, help_for("deploy", "--help"))
  end

  def test_hidden_commands_and_options_are_left_out
    out = help_for("--help")
    refute_includes out, "secret"
    refute_includes out, "debug-level"
  end

  def test_group_without_subcommand_prints_its_help
    out = help_for("db")
    assert_includes out, "Usage\n  deployer db <command> [options]"
    assert_match(/^  migrate +Run migrations$/, out)
    assert_includes out, "Run 'deployer db <command> --help' for more about a command."
  end

  def test_tool_without_arguments_prints_root_help
    assert_equal help_for("--help"), help_for
  end

  def test_nested_help
    out = help_for("help", "db", "migrate")
    assert out.start_with?("Run migrations\n\n")
    assert_includes out, "Usage\n  deployer db migrate [options]"
  end

  def test_group_with_its_own_action_marks_the_command_optional
    program = R2UI.cli "tool" do
      command(:status) { run { say "ok" } }
      run { say "root" }
    end
    assert_includes run_cli(program, "--help").out, "Usage\n  tool [command] [options]"
  end

  def test_no_escape_codes_without_color
    refute_includes help_for("deploy", "--help"), "\e["
  end

  def test_styled_with_color
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    out = help_for("deploy", "--help", color: true)
    assert_includes out, "\e["
    assert_includes out, "Usage"
    assert_includes out, "--env"
  end

  def test_help_section_extension_adds_a_section
    R2UI::CLI.extension(:help_test_notes) do
      help_section do |command, _shell|
        ["Examples", ["#{command.full_name} api", "#{command.full_name} web --env production"]] if command.name == "deploy"
      end
    end

    out = help_for("deploy", "--help")
    assert_includes out, "Examples\n  deployer deploy api\n  deployer deploy web --env production"
    assert_operator out.index("Options"), :<, out.index("Examples")
    refute_includes help_for("--help"), "Examples"
  end
end
