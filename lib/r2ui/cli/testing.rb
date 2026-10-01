# frozen_string_literal: true

require "stringio"
require_relative "../cli"

module R2UI
  module CLI
    # Test a tool without a terminal (any test framework):
    #
    #   require "r2ui/cli/testing"
    #   include R2UI::CLI::Testing
    #
    #   result = run_cli(MyTool, "deploy", "api", "--env", "production", input: "y\n")
    #   assert_equal 0, result.code
    #   assert_includes result.out, "Deployed"
    #
    # By default the shell is a pipe: no colour, no live redraw, prompts read `input` line by
    # line, exactly what CI sees. `tty: true` makes it look like a terminal (live regions draw
    # their escape codes into `out`; prompts still read `input`, as lines, unless `interactive:`).
    # `color: true` styles the output even though the test process's stdout is a pipe. The shell
    # is `width:` x `height:` (80 x env LINES, else 24), e.g. how tall a dashboard snapshot is.
    module Testing
      Result = Data.define(:code, :out, :err) do
        def success? = code.zero?
      end

      module_function

      def test_shell(input: "", tty: false, interactive: false, color: false, env: {}, width: 80, height: nil)
        Shell.new(input: StringIO.new(input), output: StringIO.new, error: StringIO.new, env:, tty:,
                  interactive:, color:, width:, height:)
      end

      def run_cli(program, *argv, **shell_options)
        shell = test_shell(**shell_options)
        code = program.call(argv.flatten.map(&:to_s), shell:)
        Result.new(code:, out: shell.output.string, err: shell.error.string)
      end

      # Runs a block with R2UI::CLI.shell swapped for a test shell; returns [value, shell].
      def with_shell(**shell_options)
        shell = test_shell(**shell_options)
        previous = CLI.instance_variable_get(:@shell)
        CLI.shell = shell
        [yield(shell), shell]
      ensure
        CLI.shell = previous
      end
    end
  end
end
