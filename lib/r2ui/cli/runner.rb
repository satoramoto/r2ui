# frozen_string_literal: true

module R2UI
  module CLI
    # Runs one argv against a Program and turns every outcome into an exit code:
    #
    #   0    the command returned (or --help, or a group run without a subcommand: its help)
    #   1    an error: CLI::Error, abort!, or anything else that escaped ("✖ message" on stderr;
    #        R2UI_TRACE=1 adds the backtrace)
    #   2    a usage error: unknown/missing/bad option, argument or command, plus a --help hint
    #   130  ctrl+c (Interrupt)
    #   n    exit_code(n) (after_run hooks still run), abort!(code: n), halt(n), or an on_error
    #        hook returning n
    #
    # A closed stdout (`tool | head`) ends quietly with 0.
    #
    # Once argv has parsed, on_exit hooks run on every way out (a normal return, exit_code, --help,
    # halt, abort!, errors, ctrl+c, `exit`) with the final code. They can't change it; an exception
    # in one is reported on stderr and the code stays.
    class Runner
      def initialize(program, shell:)
        @program = program
        @shell = shell
      end

      def call(argv)
        code = execute(argv)
      rescue SystemExit => e
        code = e.status
        raise
      ensure
        on_exit(code) if @context && code
      end

      private

      def execute(argv)
        parser = Parser.new(@program)
        invocation = parser.parse(argv)
        @context = Context.new(shell: @shell, command: invocation.command, options: invocation.options,
                               args: invocation.args, argv: invocation.argv, given: invocation.given)
        return help(invocation.command) if invocation.help

        run_hooks(:after_parse)
        parser.finish(invocation)
        return help(invocation.command) unless invocation.command.action

        run_hooks(:before_run)
        @context.call(invocation.command.action)
        run_hooks(:after_run)
        @context.exit_code
      rescue Halt => e
        e.code
      rescue Interrupt
        @shell.err_puts
        130
      rescue Errno::EPIPE
        0
      rescue StandardError => e
        report(e)
      end

      def on_exit(code)
        Extensions.hooks(:on_exit).each do |hook|
          @context.call(hook.block, code)
        rescue Halt
          nil
        rescue StandardError => e
          begin
            @shell.err_puts("#{@shell.symbol(:error)} #{e.message}")
            trace(e)
          rescue StandardError
            nil
          end
        end
      end

      def help(command)
        @shell.print(Help.new(command, @shell).to_s)
        0
      end

      def run_hooks(kind) = Extensions.hooks(kind).each { |hook| @context.call(hook.block) }

      def report(error)
        context = @context || Context.new(shell: @shell, command: error.respond_to?(:command) && error.command || @program)
        Extensions.hooks(:on_error).each do |hook|
          next unless hook.match?(error)

          code = context.call(hook.block, error)
          return code if code.is_a?(Integer)
        end

        case error
        when UsageError
          @shell.err_puts("#{@shell.symbol(:error)} #{error.message}")
          command = error.command || context.command
          @shell.err_puts(@shell.paint("Run '#{command.full_name} --help' for usage.", :muted))
        when Abort
          @shell.err_puts("#{@shell.symbol(:error)} #{error.message}") unless error.silent?
        else
          @shell.err_puts("#{@shell.symbol(:error)} #{error.message}")
          trace(error)
        end
        error.is_a?(Error) ? error.code : 1
      end

      def trace(error)
        return if error.is_a?(Error) || @shell.env["R2UI_TRACE"].to_s.empty?

        @shell.err_puts(@shell.paint(["#{error.class}: #{error.message}", *error.backtrace].join("\n  "), :muted))
      end
    end
  end
end
