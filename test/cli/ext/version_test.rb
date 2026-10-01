# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"
require_relative "../../../conformance/lib/vt"

class CLIVersionTest < Minitest::Test
  include R2UI::CLI::Testing

  def deployer(version: "1.4.0")
    ran = @ran = []
    R2UI::CLI::Program.build("deployer") do
      summary "Ship apps to the fleet"
      version version if version
      option :token, required: true, desc: "API token"
      command :deploy do
        summary "Deploy an app"
        argument :app
        run { ran << args[:app] }
      end
    end
  end

  def screen_lines(out)
    vt = Conformance::VT.new(cols: 80, rows: 30)
    vt.feed(out.gsub("\n", "\r\n"))
    vt.lines.map(&:rstrip)
  end

  def test_long_and_short_flags_print_name_and_version
    ["--version", "-V"].each do |flag|
      result = run_cli(deployer, flag)
      assert_equal [0, "deployer 1.4.0\n", ""], [result.code, result.out, result.err], flag
    end
  end

  def test_version_skips_required_options_arguments_and_the_command
    result = run_cli(deployer, "deploy", "--version")
    assert_equal [0, "deployer 1.4.0\n", ""], [result.code, result.out, result.err]
    assert_empty @ran
  end

  def test_without_the_flag_validation_still_runs
    result = run_cli(deployer, "deploy")
    assert_equal 2, result.code
    assert_equal "", result.out
  end

  def test_root_help_starts_with_the_version_and_lists_the_flag
    result = run_cli(deployer, "--help")
    assert_equal 0, result.code
    lines = result.out.lines(chomp: true)
    assert_equal "deployer 1.4.0", lines[0]
    assert_equal "", lines[1]
    assert_equal "Ship apps to the fleet", lines[2]
    assert(lines.any? { |l| l.match?(/\A  -V, --version\s+Print the version\z/) }, result.out)
  end

  def test_subcommand_help_has_no_version_line
    out = run_cli(deployer, "deploy", "--help").out
    assert_equal "Deploy an app", out.lines(chomp: true).first
  end

  def test_no_version_keyword_adds_nothing
    tool = deployer(version: nil)
    result = run_cli(tool, "--version")
    assert_equal 2, result.code
    assert_includes result.err, "--version"
    help = run_cli(tool, "--help").out
    assert_equal "Ship apps to the fleet", help.lines(chomp: true).first
    refute_includes help, "--version"
  end

  def test_terminal_output_reads_the_same_with_colour
    renderer = R2UI::Compat::Gloss::Renderer
    profile = renderer.color_profile
    renderer.color_profile = :ansi
    result = run_cli(deployer, "--version", tty: true, color: true)
    assert_equal 0, result.code
    assert_includes result.out, "\e["
    assert_equal ["deployer 1.4.0"], screen_lines(result.out).reject(&:empty?)
    help = run_cli(deployer, "--help", tty: true, color: true).out
    assert_equal "deployer 1.4.0", screen_lines(help).first
  ensure
    renderer.color_profile = profile
  end

  def test_pipe_output_has_no_escapes
    refute_includes run_cli(deployer, "--version").out, "\e"
    refute_includes run_cli(deployer, "--help").out, "\e"
  end

  def test_a_taken_short_V_leaves_only_the_long_flag
    tool = R2UI::CLI::Program.build("tool") do
      version "2.0"
      flag :verbose_mode, short: "V"
      run { say "verbose=#{options[:verbose_mode]}" }
    end
    assert_equal "tool 2.0\n", run_cli(tool, "--version").out
    assert_equal "verbose=true\n", run_cli(tool, "-V").out
  end

  def test_a_tool_defined_version_option_is_left_alone
    tool = R2UI::CLI::Program.build("tool") do
      version "2.0"
      option :version, desc: "Release to deploy"
      run { say "release=#{options[:version]}" }
    end
    assert_equal "release=3\n", run_cli(tool, "--version", "3").out
    assert_equal "tool 2.0", run_cli(tool, "--help").out.lines(chomp: true).first
  end

  def test_version_belongs_on_the_root
    error = assert_raises(ArgumentError) do
      R2UI::CLI::Program.build("tool") { command(:sub) { version "1.0" } }
    end
    assert_includes error.message, "root"
  end
end
