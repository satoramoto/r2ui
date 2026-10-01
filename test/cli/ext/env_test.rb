# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"

class EnvOptionTest < Minitest::Test
  include R2UI::CLI::Testing

  def tool
    R2UI::CLI::Program.build("deployer") do
      option :token, env: "DEPLOY_TOKEN", desc: "API token"
      option :port, :integer, short: "p", env: "DEPLOY_PORT", default: 80
      option :region, in: %w[eu us], env: "DEPLOY_REGION"
      option :tags, many: true, env: "DEPLOY_TAGS"
      flag :force, env: "DEPLOY_FORCE"
      run { say(options.to_h.slice(:token, :port, :region, :tags, :force).inspect) }
    end
  end

  def run_tool(*argv, env: {}) = run_cli(tool, *argv, env:)

  def values(result)
    assert_equal 0, result.code, result.err
    eval(result.out) # rubocop:disable Security/Eval -- our own inspect output
  end

  def test_fills_a_not_given_option_from_the_variable
    assert_equal "s3cret", values(run_tool(env: { "DEPLOY_TOKEN" => "s3cret" }))[:token]
  end

  def test_unset_variable_leaves_the_default
    result = values(run_tool)
    assert_nil result[:token]
    assert_equal 80, result[:port]
    assert_equal false, result[:force]
  end

  def test_empty_variable_counts_as_unset
    assert_equal 80, values(run_tool(env: { "DEPLOY_PORT" => "" }))[:port]
  end

  def test_command_line_wins
    env = { "DEPLOY_TOKEN" => "from-env", "DEPLOY_PORT" => "8080" }
    assert_equal "typed", values(run_tool("--token", "typed", env:))[:token]
    assert_equal 9090, values(run_tool("-p", "9090", env:))[:port]
    assert_equal 9090, values(run_tool("--port=9090", env:))[:port]
  end

  def test_value_is_converted_like_typed_input
    assert_equal 8080, values(run_tool(env: { "DEPLOY_PORT" => "8080" }))[:port]
  end

  def test_bad_value_is_a_usage_error_naming_the_variable
    result = run_tool(env: { "DEPLOY_PORT" => "eighty" })
    assert_equal 2, result.code
    assert_equal "", result.out
    assert_includes result.err, "DEPLOY_PORT"
    assert_includes result.err, "--port expects an integer, got \"eighty\""
    assert_includes result.err, "Run 'deployer --help' for usage."
  end

  def test_value_outside_the_choices_is_a_usage_error_naming_the_variable
    result = run_tool(env: { "DEPLOY_REGION" => "mars" })
    assert_equal 2, result.code
    assert_includes result.err, "DEPLOY_REGION"
    assert_includes result.err, "--region must be one of eu, us"
    assert_equal "us", values(run_tool(env: { "DEPLOY_REGION" => "us" }))[:region]
  end

  def test_a_bad_variable_is_ignored_when_the_option_is_typed
    assert_equal 1, values(run_tool("--port", "1", env: { "DEPLOY_PORT" => "eighty" }))[:port]
  end

  def test_flags_read_boolean_words
    assert_equal true, values(run_tool(env: { "DEPLOY_FORCE" => "1" }))[:force]
    assert_equal true, values(run_tool(env: { "DEPLOY_FORCE" => "yes" }))[:force]
    assert_equal false, values(run_tool(env: { "DEPLOY_FORCE" => "false" }))[:force]
    assert_equal false, values(run_tool("--no-force", env: { "DEPLOY_FORCE" => "true" }))[:force]
    result = run_tool(env: { "DEPLOY_FORCE" => "maybe" })
    assert_equal 2, result.code
    assert_includes result.err, "DEPLOY_FORCE"
  end

  def test_many_options_split_on_commas
    assert_equal %w[web api], values(run_tool(env: { "DEPLOY_TAGS" => "web, api" }))[:tags]
    assert_equal %w[cli], values(run_tool("--tags", "cli", env: { "DEPLOY_TAGS" => "web,api" }))[:tags]
  end

  def test_fills_before_the_required_check
    program = R2UI::CLI::Program.build("deployer") do
      option :token, required: true, env: "DEPLOY_TOKEN"
      run { say("token=#{options[:token]}") }
    end
    assert_equal "token=abc\n", run_cli(program, env: { "DEPLOY_TOKEN" => "abc" }).out
    result = run_cli(program)
    assert_equal 2, result.code
    assert_includes result.err, "missing required option --token"
  end

  def test_variable_wins_over_a_default_lambda
    called = false
    program = R2UI::CLI::Program.build("deployer") do
      option :token, default: -> { called = true; "fallback" }, env: "DEPLOY_TOKEN"
      run { say(options[:token]) }
    end
    assert_equal "abc\n", run_cli(program, env: { "DEPLOY_TOKEN" => "abc" }).out
    refute called, "default lambda called although the variable was set"
  end

  def test_custom_types_convert_the_variable
    program = R2UI::CLI::Program.build("deployer") do
      option :since, ->(s) { Integer(s) * 60 }, env: "SINCE_MINUTES"
      run { say(options[:since].to_s) }
    end
    assert_equal "120\n", run_cli(program, env: { "SINCE_MINUTES" => "2" }).out
  end

  def test_group_options_fill_for_subcommands
    program = R2UI::CLI::Program.build("deployer") do
      option :env, short: "e", env: "DEPLOY_ENV"
      command :deploy, "Deploy" do
        run { say("env=#{options[:env]}") }
      end
    end
    assert_equal "env=production\n", run_cli(program, "deploy", env: { "DEPLOY_ENV" => "production" }).out
  end

  def test_several_names_take_the_first_one_set
    program = R2UI::CLI::Program.build("deployer") do
      option :token, env: %w[DEPLOY_TOKEN GITHUB_TOKEN]
      run { say(options[:token].to_s) }
    end
    assert_equal "gh\n", run_cli(program, env: { "GITHUB_TOKEN" => "gh" }).out
    assert_equal "dt\n", run_cli(program, env: { "DEPLOY_TOKEN" => "dt", "GITHUB_TOKEN" => "gh" }).out
  end

  def test_a_bad_env_keyword_fails_at_definition
    error = assert_raises(ArgumentError) do
      R2UI::CLI::Program.build("deployer") { option :token, env: 42 }
    end
    assert_includes error.message, "--token"
  end
end

class EnvHelpTest < Minitest::Test
  include R2UI::CLI::Testing

  def tool
    R2UI::CLI::Program.build("deployer") do
      option :token, env: "DEPLOY_TOKEN", desc: "API token"
      option :env, short: "e", env: %w[DEPLOY_ENV RACK_ENV]
      option :tags, many: true, env: "DEPLOY_TAGS"
      option :secret, hidden: true, env: "DEPLOY_SECRET"
      option :plain
      run { nil }
    end
  end

  def test_help_lists_the_variables
    help = run_cli(tool, "--help").out
    expected = <<~TEXT
      Environment
        DEPLOY_TOKEN  --token
        DEPLOY_ENV    --env
        RACK_ENV      --env
        DEPLOY_TAGS   --tags (comma-separated)
    TEXT
    assert help.end_with?(expected), help
    refute_includes help, "DEPLOY_SECRET"
  end

  def test_help_has_no_section_without_variables
    program = R2UI::CLI::Program.build("deployer") do
      option :token
      run { nil }
    end
    refute_includes run_cli(program, "--help").out, "Environment"
  end

  def teardown
    R2UI::Compat::Gloss::Renderer.color_profile = nil
  end

  # Lipgloss picks its profile from the process's stdout, so pin one (as help_test does).
  def test_help_is_styled_on_a_terminal
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    help = run_cli(tool, "--help", tty: true, color: true).out
    assert_match(/\e\[[0-9;]*mEnvironment/, help)
    assert_match(/\e\[[0-9;]*mDEPLOY_TOKEN/, help)
    assert_includes help.gsub(/\e\[[0-9;]*m/, ""), "  DEPLOY_TOKEN  --token\n"
  end

  def test_subcommands_list_inherited_variables
    program = R2UI::CLI::Program.build("deployer") do
      option :env, env: "DEPLOY_ENV"
      command :deploy, "Deploy" do
        option :app, env: "DEPLOY_APP"
        run { nil }
      end
    end
    help = run_cli(program, "deploy", "--help").out
    assert_includes help, "Environment\n  DEPLOY_APP  --app\n  DEPLOY_ENV  --env\n"
  end
end
