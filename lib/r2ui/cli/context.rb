# frozen_string_literal: true

module R2UI
  module CLI
    # What a command's `run` block (and every runner hook) runs on. Has the parsed input, the
    # shell, every helper, and the ways out:
    #
    #   args[:app]            positional arguments by name
    #   options[:env]         options by name (defaults filled in); given?(:env) if typed
    #   abort!("msg", code: 1)   "✖ msg" on stderr, exit 1 (no message: just the exit code)
    #   halt(0)               stop now, quietly, with that code
    #   usage_error!("msg")   like a bad option: message, "--help" hint, exit 2
    class Context
      include Helpers

      attr_reader :shell, :command, :options, :args, :argv

      def initialize(shell:, command:, options: {}, args: {}, argv: [], given: [])
        @shell = shell
        @command = command
        @options = options
        @args = args
        @argv = argv
        @given = given
        @stores = {}
      end

      def program = command.root

      def given?(name) = @given.include?(name.to_sym)

      def abort!(message = nil, code: 1) = raise(Abort.new(message, code:))

      def halt(code = 0) = raise(Halt.new(code))

      def usage_error!(message) = raise(UsageError, message)

      # An extension's private Hash for this run.
      def store(name) = @stores[name.to_sym] ||= {}

      # Runs a user block here (so it sees args, options and the helpers).
      def call(block, *args) = instance_exec(*args, &block)
    end
  end
end
