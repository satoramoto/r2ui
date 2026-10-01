# frozen_string_literal: true

# r2ui for command-line tools: a declarative commands DSL plus inline helpers (tasks, prompts,
# styled output) that look like npm/pnpm on a terminal and print plain, stable lines in a pipe.
#
#   require "r2ui/cli"
#
#   R2UI.cli "deployer" do
#     summary "Ship apps to the fleet"
#     command :deploy do
#       argument :app
#       option :env, default: "staging", in: %w[staging production]
#       run do
#         confirm("Deploy #{args[:app]} to #{options[:env]}?") or abort!("cancelled")
#         tasks do
#           step("Building") { build }
#           step("Uploading") { upload }
#         end
#       end
#     end
#   end.start
#
# docs/cli.md is the design and the story list. Capabilities live one per file in
# lib/r2ui/cli/ext/ and load automatically, like the dashboard DSL's lib/r2ui/ext/.
#
# This loads r2ui's pure-Ruby Bubbletea and Lipgloss by path (as `require "r2ui"` does for
# Bubbletea), not the dashboard DSL: a CLI starts fast. `require "r2ui"` too for dashboards.
require_relative "version"
require_relative "compat/bubbletea"
require_relative "compat/lipgloss"

module R2UI
  module CLI
    # A failure the tool reports to the user: "✖ message" on stderr, exit code `code` (1).
    class Error < StandardError
      def code = 1
    end

    # Wrong arguments or options: the message, a "--help" hint, exit code 2.
    class UsageError < Error
      # The command whose usage it was (for the "--help" hint); set by the parser.
      attr_accessor :command

      def code = 2
    end

    # `abort!(message, code:)`: stop the command with a message (or none) and an exit code.
    class Abort < Error
      attr_reader :code

      def initialize(message = nil, code: 1)
        super(message)
        @code = code
        @silent = message.nil?
      end

      def silent? = @silent
    end

    # `halt(code)`: stop the command quietly. Not a StandardError, so `rescue => e` in a command
    # doesn't swallow it.
    class Halt < Exception # rubocop:disable Lint/InheritException
      attr_reader :code

      def initialize(code = 0)
        super("halt #{code}")
        @code = code
      end
    end
  end
end

require_relative "cli/shell"
require_relative "cli/live"
require_relative "cli/definition"
require_relative "cli/parser"
require_relative "cli/help"
require_relative "cli/helpers"
require_relative "cli/context"
require_relative "cli/extension"
require_relative "cli/prompt"
require_relative "cli/runner"

module R2UI
  module CLI
    extend Helpers

    class << self
      # Defines a tool: the block runs on a Builder for the root command (see docs/cli.md).
      # Returns the Program; the last one defined is `R2UI::CLI.program`.
      def define(name = File.basename($PROGRAM_NAME), &)
        @program = Program.build(name, &)
      end

      def program = @program || raise(Error, "no CLI defined: call R2UI.cli first")

      # Runs the last defined tool on ARGV and exits with its code.
      def start(argv = ARGV) = program.start(argv)

      # The process's terminal (stdin, stdout, stderr, ENV). Helpers called outside a command
      # (a plain script that includes R2UI::CLI::Helpers) use it; tests swap it.
      def shell = @shell ||= Shell.new

      attr_writer :shell

      def extension(name, &) = Extensions.register(name, &)

      # Prompt stories host bubbles components (TextInput, List, ...). Bubbles is optional, so
      # call this when a prompt is first used, never at file load. It opts into r2ui/drop_in, so
      # bubbles runs on r2ui's Bubbletea and Lipgloss.
      def require_bubbles!
        return if defined?(::Bubbles)

        require_relative "drop_in"
        begin
          require "bubbles"
        rescue LoadError
          raise Error, "this needs the bubbles gem: add `gem \"bubbles\"` to your Gemfile"
        end
      end
    end
  end

  # `R2UI.cli "name" do ... end`: the commands DSL entry point, next to R2UI.dashboard.
  def self.cli(name = File.basename($PROGRAM_NAME), &) = CLI.define(name, &)
end

# Capabilities: one self-registering file each (docs/cli.md).
R2UI::CLI::Extensions.load_all
