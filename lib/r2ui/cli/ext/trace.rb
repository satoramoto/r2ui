# frozen_string_literal: true

# c28-trace: a --trace flag that shows where an unexpected error came from.
#
#   R2UI.cli "deployer" do
#     trace_option
#     command(:deploy) { run { Deploy.call } }
#   end
#
#   $ deployer deploy --trace
#   ✖ undefined method 'call' for nil
#   NoMethodError
#     lib/deploy.rb:12:in 'Deploy.call'
#     ...
#
# `trace_option` on the root adds `--trace` to every command. With it, an unexpected error (any
# exception that isn't a CLI::Error, so not `abort!` or a usage error) prints "✖ message" on
# stderr, then the exception class and its full backtrace, and each "Caused by Class: message"
# with its own backtrace, and exits 1. On a terminal the class and backtrace are muted; off it
# they are the same plain lines, nothing else. Without `--trace` errors are reported as before
# (R2UI_TRACE=1 still works).
module R2UI
  module CLI
    module Ext
      module Trace
        module_function

        def report(shell, error)
          shell.err_puts("#{shell.symbol(:error)} #{error.message}")
          lines = [error.class.name, *frames(error)]
          seen = [error]
          cause = error.cause
          while cause && !seen.include?(cause)
            seen << cause
            lines << "Caused by #{cause.class}: #{cause.message}"
            lines.concat(frames(cause))
            cause = cause.cause
          end
          lines.each { |line| shell.err_puts(shell.paint(line, :muted)) }
          1
        end

        def frames(error) = Array(error.backtrace).map { |frame| "  #{frame}" }
      end
    end

    extension :trace do
      dsl(:command) do
        def trace_option = declare(:trace_option, true)
      end

      setup do
        flag :trace, desc: "Show the backtrace of unexpected errors" if declared(:trace_option).any?
      end

      on_error do |error|
        next if error.is_a?(Error) || !options&.fetch(:trace, false)
        next unless program.declared(:trace_option).any?

        Ext::Trace.report(shell, error)
      end
    end
  end
end
