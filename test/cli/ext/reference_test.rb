# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"

class CLIReferenceTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI

  def teardown
    R2UI::Compat::Gloss::Renderer.color_profile = nil
  end

  def tool
    CLI::Program.build("deployer") do
      summary "Ship apps to the fleet"
      reference_command
      flag :verbose, short: "v", desc: "Show more"

      command :deploy do
        summary "Deploy an app"
        description "Builds, uploads and restarts an app."
        aliases :d
        argument :app, desc: "App to deploy"
        argument :sha, required: false, desc: "Commit (default: HEAD)"
        option :env, short: "e", default: "staging", in: %w[staging production], desc: "Target"
        option :replicas, :integer, default: 2
        option :token, required: true, desc: "API token | secret"
        option :secret, hidden: true
        flag :force, short: "f", desc: "Skip the checks"
        run { say "deployed" }
      end

      command :db do
        summary "Database tasks"
        command(:migrate, "Run pending migrations") { run { say "migrated" } }
      end

      command(:internal, "Not for users", hidden: true) { run { say "secret" } }
    end
  end

  EXPECTED = <<~MD
    # deployer

    Ship apps to the fleet

    ```
    deployer <command> [options]
    ```

    | Option | Description |
    |---|---|
    | `-v, --verbose` | Show more |

    ## deployer deploy

    Deploy an app

    Builds, uploads and restarts an app.

    Aliases: `d`

    ```
    deployer deploy <app> [sha] [options]
    ```

    | Argument | Description |
    |---|---|
    | `app` | App to deploy |
    | `sha` | Commit (default: HEAD) (optional) |

    | Option | Description |
    |---|---|
    | `-e, --env <env>` | Target (staging, production; default: staging) |
    | `--replicas <replicas>` | (default: 2) |
    | `--token <token>` | API token \\| secret (required) |
    | `-f, --force` | Skip the checks |
    | `-v, --verbose` | Show more |

    ## deployer db

    Database tasks

    ```
    deployer db <command> [options]
    ```

    | Option | Description |
    |---|---|
    | `-v, --verbose` | Show more |

    ### deployer db migrate

    Run pending migrations

    ```
    deployer db migrate [options]
    ```

    | Option | Description |
    |---|---|
    | `-v, --verbose` | Show more |
  MD

  def test_prints_markdown_for_every_visible_command
    result = run_cli(tool, "reference")
    assert_equal 0, result.code
    assert_equal EXPECTED, result.out
    assert_equal "", result.err
  end

  def test_leaves_out_hidden_commands_and_options
    out = run_cli(tool, "reference").out
    refute_includes out, "internal"
    refute_includes out, "--secret"
    refute_includes out, "deployer reference"
  end

  def test_the_reference_command_is_hidden_from_help
    help = run_cli(tool, "--help").out
    refute_includes help, "reference"
    assert_includes help, "deploy"
  end

  def test_output_is_stable
    assert_equal run_cli(tool, "reference").out, run_cli(tool, "reference").out
  end

  def test_same_text_on_a_terminal_with_colour
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    out = run_cli(tool, "reference", tty: true, color: true).out
    assert_includes out, "\e["
    assert_equal EXPECTED, out.gsub(/\e\[[0-9;]*m/, "")
  end

  def test_no_reference_command_unless_asked
    program = CLI::Program.build("tool") { command(:go) { run { say "went" } } }
    result = run_cli(program, "reference")
    assert_equal 2, result.code
  end

  def test_only_on_the_root
    assert_raises(ArgumentError) do
      CLI::Program.build("tool") { command(:go) { reference_command } }
    end
  end

  def test_a_custom_name
    program = CLI::Program.build("tool") do
      reference_command :docs
      command(:go, "Go somewhere") { run { say "went" } }
    end
    result = run_cli(program, "docs")
    assert_equal 0, result.code
    assert_includes result.out, "## tool go\n\nGo somewhere\n"
    refute_includes result.out, "tool docs"
  end
end
