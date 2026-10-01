# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "r2ui/cli/testing"

class CLIConfigTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI

  def setup
    @dir = Dir.mktmpdir("r2ui-config")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def write(name, text)
    path = File.join(@dir, name)
    File.write(path, text)
    path
  end

  # deployer: a root option, a deploy command with typed options, a db group with migrate.
  def program(default_file = File.join(@dir, "deployer.yml"))
    CLI::Program.build("deployer") do
      config_file default_file
      option :region, default: "eu"
      command :deploy do
        aliases :d
        option :env, default: "staging", in: %w[staging production]
        option :replicas, :integer, default: 2
        option :tags, many: true
        option :token, env: "DEPLOYER_TEST_TOKEN"
        option :name, required: true
        flag :force
        flag :dry_run
        run { say options.slice(:region, :env, :replicas, :tags, :token, :name, :force, :dry_run).inspect }
      end
      command :db do
        command :migrate do
          option :steps, :integer, default: 1
          run { say options.slice(:region, :steps).inspect }
        end
      end
    end
  end

  def options_of(result)
    assert_equal 0, result.code, result.err
    eval(result.out) # rubocop:disable Security/Eval
  end

  def test_adds_a_config_option_shown_in_help
    result = run_cli(program, "--help")
    assert_equal 0, result.code
    assert_match(/--config <path>/, result.out)
    assert_includes result.out, "deployer.yml"
  end

  def test_a_missing_default_file_is_fine
    opts = options_of(run_cli(program, "deploy", "--name", "api"))
    assert_equal({ region: "eu", env: "staging", replicas: 2, tags: [], token: nil, name: "api", force: false,
                  dry_run: false }, opts)
  end

  def test_top_level_keys_fill_options_of_every_command
    write("deployer.yml", "region: us\nreplicas: 5\nsteps: 3\nname: api\n")
    opts = options_of(run_cli(program, "deploy"))
    assert_equal "us", opts[:region]
    assert_equal 5, opts[:replicas]
    assert_equal "api", opts[:name], "a config value satisfies a required option"

    opts = options_of(run_cli(program, "db", "migrate"))
    assert_equal({ region: "us", steps: 3 }, opts)
  end

  def test_a_command_section_fills_that_commands_options_and_wins_over_top_level
    write("deployer.yml", <<~YAML)
      replicas: 5
      deploy:
        replicas: 7
        env: production
        name: web
        tags: [a, b]
        force: true
      db:
        migrate:
          steps: 9
    YAML
    opts = options_of(run_cli(program, "deploy"))
    assert_equal 7, opts[:replicas]
    assert_equal "production", opts[:env]
    assert_equal %w[a b], opts[:tags]
    assert_equal true, opts[:force]
    assert_equal 9, options_of(run_cli(program, "db", "migrate"))[:steps]
    assert_equal 7, options_of(run_cli(program, "d"))[:replicas], "an alias reads the command's section"
  end

  def test_the_command_line_wins
    write("deployer.yml", "deploy:\n  replicas: 7\n  name: web\n  force: true\n")
    opts = options_of(run_cli(program, "deploy", "--replicas", "3", "--no-force"))
    assert_equal 3, opts[:replicas]
    assert_equal false, opts[:force]
    assert_equal "web", opts[:name]
  end

  def test_an_options_environment_variable_wins
    write("deployer.yml", "deploy:\n  token: from-file\n  name: web\n")
    opts = options_of(run_cli(program, "deploy", env: { "DEPLOYER_TEST_TOKEN" => "from-env" }))
    refute_equal "from-file", opts[:token]
    opts = options_of(run_cli(program, "deploy"))
    assert_equal "from-file", opts[:token]
  end

  def test_config_names_another_file_yaml_or_json_by_extension
    json = write("other.json", '{"region": "ap", "deploy": {"replicas": 4, "name": "x"}}')
    opts = options_of(run_cli(program, "deploy", "--config", json))
    assert_equal "ap", opts[:region]
    assert_equal 4, opts[:replicas]

    yaml = write("other.yaml", "deploy:\n  dry-run: true\n  name: y\n") # dashed keys name options too
    assert_equal true, options_of(run_cli(program, "deploy", "--config", yaml))[:dry_run]
  end

  def test_a_missing_config_file_is_a_usage_error
    result = run_cli(program, "deploy", "--name", "api", "--config", File.join(@dir, "nope.yml"))
    assert_equal 2, result.code
    assert_match(/config file .*nope\.yml.* not found/, result.err)
    assert_includes result.err, "--help"
    assert_equal "", result.out
  end

  def test_a_bad_key_is_a_usage_error_with_a_suggestion
    write("deployer.yml", "deploy:\n  replicaz: 3\n")
    result = run_cli(program, "deploy", "--name", "api")
    assert_equal 2, result.code
    assert_match(/unknown key 'replicaz' in .*deployer\.yml \(deploy\)/, result.err)
    assert_match(/Did you mean 'replicas'\?/, result.err)
  end

  def test_a_typo_anywhere_in_the_file_fails_every_command
    write("deployer.yml", "db:\n  migrate:\n    stepz: 3\n")
    assert_equal 2, run_cli(program, "deploy", "--name", "api").code
  end

  def test_a_bad_value_is_a_usage_error_naming_the_key
    write("deployer.yml", "deploy:\n  replicas: many\n")
    result = run_cli(program, "deploy", "--name", "api")
    assert_equal 2, result.code
    assert_match(/deployer\.yml: replicas .*expects an integer/, result.err)

    write("deployer.yml", "deploy:\n  env: moon\n")
    result = run_cli(program, "deploy", "--name", "api")
    assert_equal 2, result.code
    assert_match(/must be one of staging, production/, result.err)
  end

  def test_unreadable_content_is_a_usage_error
    write("deployer.yml", "deploy: [unclosed\n")
    result = run_cli(program, "deploy", "--name", "api")
    assert_equal 2, result.code
    assert_match(/deployer\.yml/, result.err)

    write("deployer.yml", "- just\n- a list\n")
    assert_equal 2, run_cli(program, "deploy", "--name", "api").code
  end

  def test_an_empty_file_is_fine
    write("deployer.yml", "")
    assert_equal 0, run_cli(program, "deploy", "--name", "api").code
  end

  def test_errors_are_plain_off_a_terminal
    write("deployer.yml", "nope: 1\n")
    result = run_cli(program, "deploy", "--name", "api")
    refute_includes result.err, "\e"
    assert_match(/\A✖ unknown key 'nope'/, result.err)
  end

  def test_a_tool_without_config_file_has_no_config_option
    tool = CLI::Program.build("plain") { run { say "ok" } }
    assert_nil tool.option(:config)
    assert_equal 2, run_cli(tool, "--config", "x.yml").code
  end
end
