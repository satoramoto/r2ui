# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require "open3"

module CompletionTestTool
  def self.build(name = "deployer")
    R2UI::CLI::Program.build(name) do
      completion
      summary "Ship apps to the fleet"
      flag :verbose, short: "v", desc: "Show more"
      option :debug_level, :integer, hidden: true

      command :deploy, "Deploy an app" do
        aliases :d, :ship
        argument :app, desc: "App to deploy"
        option :env, short: "e", default: "staging", in: %w[staging production], desc: "Target environment"
        option :replicas, :integer, desc: "Instances"
        option :config, :path, desc: "Config file"
        flag :force, short: "f", desc: "Skip the checks"
        flag :checks, default: true, desc: "Run checks"
        run {}
      end

      command :db, "Database tasks" do
        command :migrate, "Run migrations" do
          option :step, :integer, in: [1, 2, 3], desc: "How many"
          run {}
        end
      end

      command :secret, "Internal", hidden: true do
        command(:inner, "Inside a hidden one") { run {} }
      end
    end
  end

  def self.shell?(name) = system("command -v #{name} >/dev/null 2>&1")
end

class CompletionCommandTest < Minitest::Test
  include R2UI::CLI::Testing

  def tool = @tool ||= CompletionTestTool.build

  def script(shell)
    result = run_cli(tool, "completion", shell)
    assert_equal 0, result.code, result.err
    assert_equal "", result.err
    result.out
  end

  def test_without_the_keyword_there_is_no_completion_command
    plain = R2UI::CLI::Program.build("tool") { command(:go, "Go") { run {} } }
    result = run_cli(plain, "completion", "bash")
    assert_equal 2, result.code
    refute_includes run_cli(plain, "--help").out, "completion"
  end

  def test_root_help_lists_the_command
    assert_match(/^  completion\s+Print a shell completion script$/, run_cli(tool, "--help").out)
  end

  def test_keyword_belongs_on_the_root
    error = assert_raises(ArgumentError) do
      R2UI::CLI::Program.build("tool") { command(:sub) { completion } }
    end
    assert_includes error.message, "root"
  end

  def test_each_shell_prints_commands_aliases_options_and_choices
    %w[bash zsh fish].each do |shell|
      out = script(shell)
      %w[deploy ship db migrate completion --env --replicas --force --no-checks --verbose staging production].each do |word|
        word = "-l #{word.delete_prefix("--")}" if shell == "fish" && word.start_with?("--") # fish: complete -l env
        assert_includes out, word, "#{shell} script lacks #{word}"
      end
    end
  end

  def test_hidden_commands_and_options_are_left_out
    %w[bash zsh fish].each do |shell|
      out = script(shell)
      %w[secret inner debug-level debug_level].each { |word| refute_includes out, word, "#{shell} script has #{word}" }
    end
  end

  def test_scripts_are_plain_even_on_a_terminal
    result = run_cli(tool, "completion", "zsh", tty: true, color: true)
    assert_equal 0, result.code
    refute_includes result.out, "\e["
    assert_equal script("zsh"), result.out
  end

  def test_a_terminal_gets_a_hint_on_stderr_and_a_pipe_does_not
    result = run_cli(tool, "completion", "bash", tty: true)
    assert_includes result.err, %(eval "$(deployer completion bash)")
    assert_equal "", run_cli(tool, "completion", "bash").err
  end

  def test_unknown_shell_is_a_usage_error
    result = run_cli(tool, "completion", "zssh")
    assert_equal 2, result.code
    assert_includes result.err, "unknown shell 'zssh'"
    assert_includes result.err, "Did you mean 'zsh'?"
    assert_equal "", result.out
  end

  def test_short_typos_suggest_the_shell
    { "zhs" => "zsh", "bsah" => "bash", "fsih" => "fish", "zs" => "zsh", "bahs" => "bash" }.each do |typo, shell|
      result = run_cli(tool, "completion", typo)
      assert_equal 2, result.code
      assert_includes result.err, "Did you mean '#{shell}'?", typo
    end
    refute_includes run_cli(tool, "completion", "powershell").err, "Did you mean"
  end

  def test_missing_shell_is_a_usage_error
    result = run_cli(tool, "completion")
    assert_equal 2, result.code
    assert_includes result.err, "missing argument <shell>"
  end

  def test_help_shows_how_to_load_each_shell
    out = run_cli(tool, "completion", "--help").out
    assert_includes out, "Setup"
    assert_includes out, %(eval "$(deployer completion bash)")
    assert_includes out, %(eval "$(deployer completion zsh)")
    assert_includes out, "deployer completion fish | source"
  end

  def test_bash_accepts_the_script
    skip "bash not installed" unless CompletionTestTool.shell?("bash")
    _, err, status = Open3.capture3("bash", "-n", stdin_data: script("bash"))
    assert status.success?, err
  end

  def test_zsh_accepts_the_script
    skip "zsh not installed" unless CompletionTestTool.shell?("zsh")
    _, err, status = Open3.capture3("zsh", "-n", stdin_data: script("zsh"))
    assert status.success?, err
  end

  def test_zsh_registers_the_function_after_compinit
    skip "zsh not installed" unless CompletionTestTool.shell?("zsh")
    driver = 'autoload -U compinit && compinit -u -D && eval "$SCRIPT" && print -r -- $_comps[deployer]'
    out, err, status = Open3.capture3({ "SCRIPT" => script("zsh") }, "zsh", "-f", "-c", driver)
    assert status.success?, err
    assert_equal "_deployer\n", out
  end

  def test_fish_accepts_the_script
    skip "fish not installed" unless CompletionTestTool.shell?("fish")
    _, err, status = Open3.capture3("fish", "--no-execute", stdin_data: script("fish"))
    assert status.success?, err
  end

  def test_odd_tool_names_make_valid_scripts
    skip "bash not installed" unless CompletionTestTool.shell?("bash")
    out = run_cli(CompletionTestTool.build("my-tool.rb"), "completion", "bash").out
    _, err, status = Open3.capture3("bash", "-n", stdin_data: out)
    assert status.success?, err
  end
end

# What bash offers after a TAB, through the function the script registers for the tool.
class CompletionBashTest < Minitest::Test
  include R2UI::CLI::Testing

  DRIVER = <<~'BASH'
    eval "$SCRIPT"
    COMP_WORDBREAKS=$' \t\n"\'><=;|&(:'
    read -ra spec <<< "$(complete -p deployer)"
    COMP_LINE=$LINE
    COMP_POINT=${#COMP_LINE}
    COMPREPLY=()
    "${spec[${#spec[@]}-2]}" deployer
    printf '%s\n' "${COMPREPLY[@]}"
  BASH

  def setup
    skip "bash not installed" unless CompletionTestTool.shell?("bash")
    @script = run_cli(CompletionTestTool.build, "completion", "bash").out
  end

  def offers(line)
    out, err, status = Open3.capture3({ "SCRIPT" => @script, "LINE" => line }, "bash", "-c", DRIVER)
    assert status.success?, err
    out.split("\n").reject(&:empty?)
  end

  def test_commands_and_aliases
    assert_equal %w[completion d db deploy help ship], offers("deployer ").sort
  end

  def test_a_prefix_narrows_them
    assert_equal %w[d db deploy], offers("deployer d").sort
  end

  def test_hidden_commands_are_not_offered
    assert_empty offers("deployer se")
  end

  def test_options_include_inherited_ones_and_negations
    words = offers("deployer deploy --")
    assert_equal %w[--checks --config --env --force --help --no-checks --replicas --verbose], words.sort
  end

  def test_choices_after_an_option
    assert_equal %w[production staging], offers("deployer deploy -e ").sort
    assert_equal %w[staging], offers("deployer ship --env st").sort
  end

  def test_choices_after_an_equals_sign
    assert_equal %w[production], offers("deployer d --env=pr")
  end

  def test_nested_commands_and_their_choices
    assert_equal %w[migrate], offers("deployer db ")
    assert_equal %w[1 2 3], offers("deployer db migrate --step ")
  end

  def test_options_before_the_command_are_skipped
    assert_includes offers("deployer -v deploy --e"), "--env"
  end

  def test_help_completes_command_names
    assert_includes offers("deployer help dep"), "deploy"
  end

  def test_arguments_get_no_command_names
    assert_empty offers("deployer deploy api ")
    assert_empty offers("deployer deploy -e production ")
  end

  def test_the_completion_command_offers_shells
    assert_equal %w[bash fish zsh], offers("deployer completion ").sort
  end
end
