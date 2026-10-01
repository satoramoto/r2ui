# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"

# How argv turns into options, arguments and a command, as a user of the tool sees it.
class CLIParserTest < Minitest::Test
  include R2UI::CLI::Testing

  # A tool whose commands print what they received, one value per line.
  def tool
    @tool ||= R2UI.cli "tool" do
      flag :verbose, short: "v", desc: "Say more"

      command :deploy, "Deploy an app" do
        aliases :d, :ship
        argument :app
        argument :sha, required: false
        option :env, short: "e", default: "staging", in: %w[staging production]
        option :count, :integer, short: "n", default: 1
        option :ratio, :float
        option :tag, many: true
        option :name, ->(s) { s.upcase }
        flag :force, short: "f"
        run do
          say "app=#{args[:app]} sha=#{args[:sha].inspect}"
          say "env=#{options[:env]} count=#{options[:count].inspect} ratio=#{options[:ratio].inspect}"
          say "tag=#{options[:tag].inspect} name=#{options[:name].inspect}"
          say "force=#{options[:force]} verbose=#{options[:verbose]}"
          say "given env=#{given?(:env)} force=#{given?(:force)}"
        end
      end

      command :db, "Database tasks" do
        option :url, default: "postgres://local"
        command :migrate, "Run migrations" do
          argument :steps, :integer, default: 1
          run { say "migrate steps=#{args[:steps]} url=#{options[:url]} verbose=#{options[:verbose]}" }
        end
        command :seed, "Seed data" do
          argument :files, many: true, required: false
          run { say "seed #{args[:files].inspect}" }
        end
      end

      command :add, "Add numbers" do
        argument :a, :integer
        argument :b, :integer, default: 0
        run { say "sum=#{args[:a] + args[:b]}" }
      end

      command :copy, "Copy files" do
        argument :sources, many: true, required: true
        run { say "copy #{args[:sources].inspect}" }
      end
    end
  end

  def run_tool(*argv) = run_cli(tool, *argv)

  def assert_ok(result)
    assert_equal 0, result.code, "stderr: #{result.err}"
    result
  end

  def assert_usage_error(result, message)
    assert_equal 2, result.code
    assert_empty result.out
    assert_includes result.err, message
    result
  end

  # Options

  def test_long_option_with_separate_value
    assert_includes assert_ok(run_tool("deploy", "api", "--env", "production")).out, "env=production"
  end

  def test_long_option_with_equals_value
    assert_includes assert_ok(run_tool("deploy", "api", "--env=production")).out, "env=production"
  end

  def test_short_option_with_separate_value
    assert_includes assert_ok(run_tool("deploy", "api", "-e", "production")).out, "env=production"
  end

  def test_short_option_with_attached_value
    assert_includes assert_ok(run_tool("deploy", "api", "-eproduction")).out, "env=production"
  end

  def test_clustered_short_booleans
    out = assert_ok(run_tool("deploy", "api", "-vf")).out
    assert_includes out, "force=true verbose=true"
  end

  def test_clustered_short_boolean_then_value_option
    out = assert_ok(run_tool("deploy", "api", "-fn3")).out
    assert_includes out, "count=3"
    assert_includes out, "force=true"
  end

  def test_no_prefix_turns_a_flag_off
    out = assert_ok(run_tool("deploy", "api", "--force", "--no-force")).out
    assert_includes out, "force=false"
  end

  def test_boolean_with_explicit_value
    assert_includes assert_ok(run_tool("deploy", "api", "--force=yes")).out, "force=true"
    assert_includes assert_ok(run_tool("deploy", "api", "--force=off")).out, "force=false"
  end

  def test_bad_boolean_value_is_a_usage_error
    assert_usage_error(run_tool("deploy", "api", "--force=maybe"), "--force expects true or false")
  end

  def test_no_prefix_on_a_value_option_is_unknown
    assert_usage_error(run_tool("deploy", "api", "--no-env"), "unknown option '--no-env'")
  end

  def test_double_dash_ends_options
    out = assert_ok(run_tool("deploy", "--", "--force", "-v")).out
    assert_includes out, 'app=--force sha="-v"'
    assert_includes out, "force=false verbose=false"
  end

  def test_options_before_and_after_positionals
    before = assert_ok(run_tool("deploy", "--env", "production", "api", "abc123")).out
    after = assert_ok(run_tool("deploy", "api", "abc123", "--env", "production")).out
    [before, after].each do |out|
      assert_includes out, 'app=api sha="abc123"'
      assert_includes out, "env=production"
    end
  end

  def test_group_option_applies_to_subcommands
    out = assert_ok(run_tool("db", "--url", "postgres://prod", "migrate")).out
    assert_includes out, "url=postgres://prod"
    out = assert_ok(run_tool("db", "migrate", "--url", "postgres://prod")).out
    assert_includes out, "url=postgres://prod"
  end

  def test_root_option_applies_anywhere_in_the_tree
    assert_includes assert_ok(run_tool("--verbose", "db", "migrate")).out, "verbose=true"
    assert_includes assert_ok(run_tool("db", "migrate", "-v")).out, "verbose=true"
  end

  def test_group_option_is_not_known_to_sibling_commands
    assert_usage_error(run_tool("deploy", "api", "--url", "x"), "unknown option '--url'")
  end

  def test_integer_option
    assert_includes assert_ok(run_tool("deploy", "api", "--count", "42")).out, "count=42"
  end

  def test_integer_option_rejects_a_non_integer
    result = assert_usage_error(run_tool("deploy", "api", "--count", "lots"), "--count expects an integer")
    assert_includes result.err, '"lots"'
    assert_includes result.err, "Run 'tool deploy --help' for usage."
  end

  def test_integer_option_rejects_a_float
    assert_usage_error(run_tool("deploy", "api", "--count", "1.5"), "--count expects an integer")
  end

  def test_float_option
    assert_includes assert_ok(run_tool("deploy", "api", "--ratio", "0.25")).out, "ratio=0.25"
  end

  def test_float_option_rejects_text
    assert_usage_error(run_tool("deploy", "api", "--ratio", "half"), "--ratio expects a float")
  end

  def test_callable_type_converts_the_value
    assert_includes assert_ok(run_tool("deploy", "api", "--name", "web")).out, 'name="WEB"'
  end

  def test_callable_type_error_is_a_usage_error
    program = R2UI.cli "tool" do
      option :port, ->(s) { Integer(s).between?(1, 65_535) ? Integer(s) : raise(ArgumentError, "is out of range") }
      run { say "port=#{options[:port]}" }
    end
    assert_includes assert_ok(run_cli(program, "--port", "8080")).out, "port=8080"
    assert_usage_error(run_cli(program, "--port", "70000"), "--port is out of range")
  end

  def test_choices_accept_a_listed_value
    assert_includes assert_ok(run_tool("deploy", "api", "--env", "production")).out, "env=production"
  end

  def test_choices_reject_an_unlisted_value
    assert_usage_error(run_tool("deploy", "api", "--env", "qa"), "--env must be one of staging, production")
  end

  def test_many_collects_repeats
    out = assert_ok(run_tool("deploy", "api", "--tag", "a", "--tag=b")).out
    assert_includes out, 'tag=["a", "b"]'
  end

  def test_many_defaults_to_an_empty_list
    assert_includes assert_ok(run_tool("deploy", "api")).out, "tag=[]"
  end

  def test_defaults_fill_missing_options
    out = assert_ok(run_tool("deploy", "api")).out
    assert_includes out, "env=staging count=1 ratio=nil"
    assert_includes out, "name=nil"
    assert_includes out, "force=false verbose=false"
  end

  def test_lambda_default_is_called_only_when_the_option_is_missing
    calls = 0
    program = R2UI.cli "tool" do
      option :token, default: -> { calls += 1; "from-env" }
      run { say "token=#{options[:token]}" }
    end

    assert_includes assert_ok(run_cli(program)).out, "token=from-env"
    assert_equal 1, calls
    assert_includes assert_ok(run_cli(program, "--token", "typed")).out, "token=typed"
    assert_equal 1, calls
  end

  def test_string_default_is_converted_to_the_option_type
    program = R2UI.cli "tool" do
      option :port, :integer, default: -> { "8080" }
      run { say "port=#{options[:port].inspect}" }
    end
    assert_includes assert_ok(run_cli(program)).out, "port=8080"
  end

  def test_required_option_must_be_given
    program = R2UI.cli "tool" do
      option :token, required: true
      run { say "token=#{options[:token]}" }
    end
    assert_usage_error(run_cli(program), "missing required option --token")
    assert_includes assert_ok(run_cli(program, "--token", "t")).out, "token=t"
  end

  def test_required_option_is_satisfied_by_a_default
    program = R2UI.cli "tool" do
      option :token, required: true, default: -> { "from-env" }
      run { say "token=#{options[:token]}" }
    end
    assert_includes assert_ok(run_cli(program)).out, "token=from-env"
  end

  def test_given_tells_typed_options_from_defaults
    assert_includes assert_ok(run_tool("deploy", "api")).out, "given env=false force=false"
    assert_includes assert_ok(run_tool("deploy", "api", "--env", "staging", "-f")).out, "given env=true force=true"
  end

  def test_option_missing_its_value
    assert_usage_error(run_tool("deploy", "api", "--env"), "option --env needs a value")
    assert_usage_error(run_tool("deploy", "api", "-e"), "option -e (--env) needs a value")
  end

  def test_unknown_long_option_suggests_a_near_one
    assert_usage_error(run_tool("deploy", "api", "--evn", "x"), "unknown option '--evn'. Did you mean '--env'?")
  end

  def test_unknown_short_option
    assert_usage_error(run_tool("deploy", "api", "-z"), "unknown option '-z'")
  end

  def test_dashes_in_option_names_map_to_underscores
    program = R2UI.cli "tool" do
      flag :dry_run
      run { say "dry_run=#{options[:dry_run]}" }
    end
    assert_includes assert_ok(run_cli(program, "--dry-run")).out, "dry_run=true"
    assert_includes assert_ok(run_cli(program, "--no-dry-run")).out, "dry_run=false"
  end

  # Arguments

  def test_required_and_optional_arguments
    assert_includes assert_ok(run_tool("deploy", "api")).out, "app=api sha=nil"
    assert_includes assert_ok(run_tool("deploy", "api", "abc")).out, 'app=api sha="abc"'
  end

  def test_missing_required_argument
    result = assert_usage_error(run_tool("deploy"), "missing argument <app>")
    assert_includes result.err, "Run 'tool deploy --help' for usage."
  end

  def test_unexpected_argument
    assert_usage_error(run_tool("deploy", "api", "abc", "extra"), 'unexpected argument "extra"')
  end

  def test_argument_default
    assert_includes assert_ok(run_tool("db", "migrate")).out, "steps=1"
    assert_includes assert_ok(run_tool("db", "migrate", "3")).out, "steps=3"
  end

  def test_typed_argument_conversion
    assert_includes assert_ok(run_tool("add", "2", "3")).out, "sum=5"
    assert_includes assert_ok(run_tool("add", "2")).out, "sum=2"
    assert_usage_error(run_tool("add", "two"), '<a> expects an integer, got "two"')
  end

  def test_many_argument_takes_the_rest
    assert_includes assert_ok(run_tool("db", "seed", "a.sql", "b.sql", "c.sql")).out, 'seed ["a.sql", "b.sql", "c.sql"]'
  end

  def test_optional_many_argument_may_be_empty
    assert_includes assert_ok(run_tool("db", "seed")).out, "seed []"
  end

  def test_required_many_argument_needs_one
    assert_usage_error(run_tool("copy"), "missing argument <sources...>")
    assert_includes assert_ok(run_tool("copy", "x")).out, 'copy ["x"]'
  end

  def test_negative_numbers_are_positionals
    assert_includes assert_ok(run_tool("add", "-5", "2")).out, "sum=-3"
    assert_includes assert_ok(run_tool("add", "1", "-4")).out, "sum=-3"
  end

  def test_negative_float_is_a_positional
    program = R2UI.cli "tool" do
      argument :x, :float
      run { say "x=#{args[:x]}" }
    end
    assert_includes assert_ok(run_cli(program, "-1.5")).out, "x=-1.5"
  end

  # Commands

  def test_subcommand_runs
    assert_includes assert_ok(run_tool("deploy", "api")).out, "app=api"
  end

  def test_nested_group
    assert_equal "migrate steps=2 url=postgres://local verbose=false\n", assert_ok(run_tool("db", "migrate", "2")).out
  end

  def test_aliases
    assert_includes assert_ok(run_tool("d", "api")).out, "app=api"
    assert_includes assert_ok(run_tool("ship", "api")).out, "app=api"
  end

  def test_unknown_command_suggests_a_near_one
    result = assert_usage_error(run_tool("deplyo"), "unknown command 'deplyo' for 'tool'. Did you mean 'deploy'?")
    assert_includes result.err, "Run 'tool --help' for usage."
  end

  def test_unknown_nested_command_suggests_a_near_one
    result = assert_usage_error(run_tool("db", "migrat"), "unknown command 'migrat' for 'tool db'. Did you mean 'migrate'?")
    assert_includes result.err, "Run 'tool db --help' for usage."
  end

  def test_unknown_command_without_a_near_one
    result = assert_usage_error(run_tool("zzzzzz"), "unknown command 'zzzzzz' for 'tool'")
    refute_includes result.err, "Did you mean"
  end

  def test_hidden_command_still_runs
    program = R2UI.cli "tool" do
      command(:secret, hidden: true) { run { say "found" } }
      command(:open) { run { say "open" } }
    end
    assert_equal "found\n", assert_ok(run_cli(program, "secret")).out
  end
end
