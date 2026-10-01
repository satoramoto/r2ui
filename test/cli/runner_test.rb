# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"

# What a run ends with (exit code, stdout, stderr), extension hooks around it, and the
# definition errors a tool author sees.
class CLIRunnerTest < Minitest::Test
  include R2UI::CLI::Testing

  EXTENSIONS = %i[runner_test_hooks runner_test_fill runner_test_errors runner_test_setup runner_test_dsl
                  runner_test_dsl_again runner_test_helpers].freeze

  def teardown
    EXTENSIONS.each { |name| R2UI::CLI::Extensions.remove(name) }
  end

  def tool(&run_block)
    R2UI.cli "tool" do
      run(&run_block)
    end
  end

  # Exit codes

  def test_success_is_zero
    result = run_cli(tool { say "hello" })
    assert_equal 0, result.code
    assert_equal "hello\n", result.out
    assert_empty result.err
  end

  def test_cli_error_is_one_with_a_message
    result = run_cli(tool { raise R2UI::CLI::Error, "config not found" })
    assert_equal 1, result.code
    assert_equal "✖ config not found\n", result.err
  end

  def test_abort_is_one_with_a_message
    result = run_cli(tool { abort!("cancelled") })
    assert_equal 1, result.code
    assert_equal "✖ cancelled\n", result.err
  end

  def test_abort_with_a_code
    result = run_cli(tool { abort!("nothing to do", code: 3) })
    assert_equal 3, result.code
    assert_equal "✖ nothing to do\n", result.err
  end

  def test_silent_abort
    result = run_cli(tool { abort!(code: 4) })
    assert_equal 4, result.code
    assert_empty result.err
    assert_empty result.out
  end

  def test_unexpected_exception_is_one_without_a_backtrace
    result = run_cli(tool { raise "boom" })
    assert_equal 1, result.code
    assert_equal "✖ boom\n", result.err
  end

  def test_trace_env_prints_a_backtrace
    result = run_cli(tool { raise "boom" }, env: { "R2UI_TRACE" => "1" })
    assert_equal 1, result.code
    assert_includes result.err, "✖ boom"
    assert_includes result.err, "RuntimeError: boom"
    assert_includes result.err, "runner_test.rb"
  end

  def test_halt_stops_quietly_with_its_code
    result = run_cli(tool do
      say "before"
      halt 5
      say "after"
    end)
    assert_equal 5, result.code
    assert_equal "before\n", result.out
    assert_empty result.err
  end

  def test_halt_defaults_to_zero
    assert_equal 0, run_cli(tool { halt }).code
  end

  def test_rescue_in_a_command_does_not_swallow_halt
    result = run_cli(tool do
      begin
        halt 6
      rescue => e
        say "rescued #{e.message}"
      end
      say "after"
    end)
    assert_equal 6, result.code
    assert_empty result.out
  end

  def test_usage_error_is_two_with_a_help_hint
    program = R2UI.cli "tool" do
      command :deploy do
        argument :app
        run { say "x" }
      end
    end
    result = run_cli(program, "deploy", "a", "b")
    assert_equal 2, result.code
    assert_equal "✖ unexpected argument \"b\"\nRun 'tool deploy --help' for usage.\n", result.err
  end

  def test_usage_error_raised_by_the_command
    result = run_cli(tool { usage_error!("pick one of --a or --b") })
    assert_equal 2, result.code
    assert_equal "✖ pick one of --a or --b\nRun 'tool --help' for usage.\n", result.err
  end

  def test_interrupt_is_130
    result = run_cli(tool { raise Interrupt })
    assert_equal 130, result.code
  end

  def test_closed_stdout_ends_quietly
    result = run_cli(tool { raise Errno::EPIPE })
    assert_equal 0, result.code
    assert_empty result.err
  end

  # Extension hooks

  def test_before_run_and_after_run_wrap_the_command
    R2UI::CLI.extension(:runner_test_hooks) do
      before_run { say "before #{command.name}" }
      after_run { say "after #{command.name}" }
    end
    result = run_cli(tool { say "run" })
    assert_equal 0, result.code
    assert_equal "before tool\nrun\nafter tool\n", result.out
  end

  def test_after_run_is_skipped_when_the_command_fails
    R2UI::CLI.extension(:runner_test_hooks) { after_run { say "after" } }
    result = run_cli(tool { abort!("no") })
    assert_equal 1, result.code
    assert_empty result.out
  end

  def test_before_run_can_halt
    R2UI::CLI.extension(:runner_test_hooks) { before_run { halt 7 if options[:skip] } }
    program = R2UI.cli "tool" do
      flag :skip
      run { say "ran" }
    end
    assert_equal 7, run_cli(program, "--skip").code
    assert_equal "ran\n", run_cli(program).out
  end

  def test_after_parse_fills_an_option_before_defaults_and_required_checks
    R2UI::CLI.extension(:runner_test_fill) do
      after_parse { options[:token] ||= "from-keychain" if command.option(:token) }
    end
    program = R2UI.cli "tool" do
      option :token, required: true, default: "from-default"
      run { say "token=#{options[:token]} given=#{given?(:token)}" }
    end
    assert_equal "token=from-keychain given=false\n", run_cli(program).out
    assert_equal "token=typed given=true\n", run_cli(program, "--token", "typed").out
  end

  # A --version-style hook halts before required options and arguments are checked.
  def test_after_parse_halt_skips_argument_and_required_checks
    R2UI::CLI.extension(:runner_test_fill) do
      after_parse { (say("tool 1.0") || halt(0)) if options[:version] }
    end
    program = R2UI.cli "tool" do
      flag :version
      option :token, required: true
      argument :app
      run { say "ran #{args[:app]}" }
    end
    result = run_cli(program, "--version")
    assert_equal [0, "tool 1.0\n", ""], [result.code, result.out, result.err]
    result = run_cli(program, "--token", "t")
    assert_equal 2, result.code
    assert_includes result.err, "missing argument <app>"
    assert_includes result.err, "Run 'tool --help' for usage."
    assert_equal "ran api\n", run_cli(program, "api", "--token", "t").out
  end

  def test_on_error_returning_an_integer_replaces_the_report
    R2UI::CLI.extension(:runner_test_errors) do
      on_error(KeyError) do |error|
        shell.err_puts "missing key: #{error.key}"
        9
      end
    end
    result = run_cli(tool { {}.fetch(:region) })
    assert_equal 9, result.code
    assert_equal "missing key: region\n", result.err
  end

  def test_on_error_returning_nil_keeps_the_report
    seen = []
    R2UI::CLI.extension(:runner_test_errors) { on_error { |error| seen << error.message and nil } }
    result = run_cli(tool { raise "boom" })
    assert_equal 1, result.code
    assert_equal "✖ boom\n", result.err
    assert_equal ["boom"], seen
  end

  def test_on_error_only_sees_matching_errors
    R2UI::CLI.extension(:runner_test_errors) { on_error(KeyError) { 9 } }
    result = run_cli(tool { raise "boom" })
    assert_equal 1, result.code
    assert_equal "✖ boom\n", result.err
  end

  def test_on_error_sees_usage_errors
    R2UI::CLI.extension(:runner_test_errors) { on_error(R2UI::CLI::UsageError) { 64 } }
    program = R2UI.cli("tool") { run { say "x" } }
    result = run_cli(program, "--nope")
    assert_equal 64, result.code
    assert_empty result.err
  end

  def test_setup_runs_on_the_root_builder
    R2UI::CLI.extension(:runner_test_setup) do
      setup do
        flag :quiet, short: "q", desc: "Say less"
        command(:about, "About this tool") { run { say "about #{program.name}" } }
      end
    end
    program = R2UI.cli "tool" do
      command(:go) { run { say "quiet=#{options[:quiet]}" } }
    end
    assert_equal "quiet=true\n", run_cli(program, "go", "-q").out
    assert_equal "about tool\n", run_cli(program, "about").out
    help = run_cli(program, "--help").out
    assert_includes help, "--quiet"
    assert_includes help, "About this tool"
  end

  def test_dsl_adds_a_keyword_to_commands
    R2UI::CLI.extension(:runner_test_dsl) do
      dsl(:command) { def owner(name) = declare(:runner_test_owner, name) }
      before_run { say "owned by #{command.declared(:runner_test_owner).last}" if command.declared(:runner_test_owner).any? }
    end
    program = R2UI.cli "tool" do
      command :deploy do
        owner "platform"
        run { say "deploy" }
      end
    end
    assert_equal "owned by platform\ndeploy\n", run_cli(program, "deploy").out
  end

  def test_duplicate_dsl_keyword_raises
    R2UI::CLI.extension(:runner_test_dsl) { dsl(:command) { def owner(name) = declare(:owner, name) } }
    error = assert_raises(R2UI::CLI::Error) do
      R2UI::CLI.extension(:runner_test_dsl_again) { dsl(:command) { def owner(name) = name } }
    end
    assert_includes error.message, "owner"
    assert_nil R2UI::CLI::Extensions[:runner_test_dsl_again]
  end

  def test_dsl_keyword_clashing_with_a_core_keyword_raises
    assert_raises(R2UI::CLI::Error) do
      R2UI::CLI.extension(:runner_test_dsl) { dsl(:command) { def summary(text) = text } }
    end
  end

  def test_helpers_are_callable_in_run_blocks_and_on_the_module
    R2UI::CLI.extension(:runner_test_helpers) do
      helpers { def runner_test_shout(text) = say(text.upcase) }
    end
    result = run_cli(tool { runner_test_shout "hi" })
    assert_equal "HI\n", result.out

    _, shell = with_shell { R2UI::CLI.runner_test_shout("there") }
    assert_equal "THERE\n", shell.output.string
  end

  # Definition errors

  def test_duplicate_command_raises
    error = assert_raises(ArgumentError) do
      R2UI.cli("tool") do
        command(:deploy) { run { nil } }
        command(:deploy) { run { nil } }
      end
    end
    assert_includes error.message, "deploy is defined twice"
  end

  def test_command_clashing_with_an_alias_raises
    assert_raises(ArgumentError) do
      R2UI.cli("tool") do
        command(:deploy) { aliases :ship }
        command(:ship) { run { nil } }
      end
    end
  end

  def test_option_clashing_with_an_inherited_one_raises
    error = assert_raises(ArgumentError) do
      R2UI.cli("tool") do
        option :env
        command(:deploy) { option :env }
      end
    end
    assert_includes error.message, "--env clashes with --env"
  end

  def test_short_option_clash_raises
    assert_raises(ArgumentError) do
      R2UI.cli("tool") do
        flag :verbose, short: "v"
        flag :version, short: "v"
      end
    end
  end

  def test_short_h_is_reserved_for_help
    error = assert_raises(ArgumentError) { R2UI.cli("tool") { option :host, short: "h" } }
    assert_includes error.message, "-h is reserved for --help"
    assert_raises(ArgumentError) { R2UI.cli("tool") { flag :help } }
  end

  def test_short_option_must_be_one_character
    assert_raises(ArgumentError) { R2UI.cli("tool") { option :env, short: "en" } }
  end

  def test_required_argument_after_an_optional_one_raises
    error = assert_raises(ArgumentError) do
      R2UI.cli("tool") do
        argument :sha, required: false
        argument :app
      end
    end
    assert_includes error.message, "required argument <app> after an optional one"
  end

  def test_argument_after_a_many_argument_raises
    assert_raises(ArgumentError) do
      R2UI.cli("tool") do
        argument :files, many: true
        argument :dest
      end
    end
  end

  def test_run_needs_a_block
    assert_raises(ArgumentError) { R2UI.cli("tool") { run } }
  end
end
