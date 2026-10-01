# frozen_string_literal: true

# c06-log: styled log levels, one line per message.
#
#   info    "Using node 20"                # ℹ Using node 20             stdout
#   success "Installed 42 packages"        # ✔ Installed 42 packages    stdout
#   warn    "3 deprecated packages"        # ⚠ 3 deprecated packages    stderr
#   error   "Build failed"                 # ✖ Build failed             stderr
#   debug   "cache hit for react@18"       # • cache hit for react@18   stderr, only when asked
#
# On a terminal the symbol takes its level's colour (blue, green, yellow, red) and the message
# stays plain; a debug line is muted. Off a terminal (a pipe, CI, NO_COLOR) the same lines print
# with no escape codes. A multi-line message indents its other lines under the first:
#
#   ⚠ Peer dependency missing
#     react@18 is required by app
#
# `info` and `success` write to stdout; `warn`, `error` and `debug` to stderr, so `tool | jq`
# stays clean. `debug` prints only when the command's `options[:verbose]` is true (a `flag
# :verbose` on the root gives every command `-v`) or the `R2UI_DEBUG` variable is set (and not
# "0"); otherwise it does nothing.
#
# `warn` replaces Kernel#warn inside commands and in scripts that `include R2UI::CLI::Helpers`
# (several messages become one entry, a line each; Kernel's `uplevel:` and `category:` are
# accepted and ignored). Inside a Live region (tasks, spinners, progress) the lines print above
# it. Every helper returns nil.
module R2UI
  module CLI
    module Ext
      module Log
        # Level => [theme symbol, theme style for the symbol, stream].
        LEVELS = {
          info: [:info, :info, :out],
          success: [:success, :success, :out],
          warn: [:warn, :warn, :err],
          error: [:error, :error, :err],
          debug: [:bullet, :muted, :err]
        }.freeze

        module_function

        def write(shell, level, message)
          symbol_name, style, stream = LEVELS.fetch(level)
          lines = message.to_s.chomp.split("\n", -1)
          lines = [""] if lines.empty?
          symbol = shell.paint(shell.theme.symbol(symbol_name), style)
          first, *rest = lines
          rest = rest.map { |line| line.empty? ? line : "  #{line}" }
          rest = rest.map { |line| shell.paint(line, :muted) } if level == :debug
          first = shell.paint(first, :muted) if level == :debug
          text = ["#{symbol} #{first}", *rest].join("\n")
          stream == :out ? shell.puts(text) : shell.err_puts(text)
          nil
        end

        def debug?(context)
          value = context.shell.env["R2UI_DEBUG"]
          return true if value && !value.empty? && value != "0"

          context.is_a?(Context) && context.options[:verbose] == true
        end
      end
    end

    extension :log do
      helpers do
        def info(message) = Ext::Log.write(shell, :info, message)

        def success(message) = Ext::Log.write(shell, :success, message)

        # Kernel#warn's signature, so it can stand in for it.
        def warn(*messages, uplevel: nil, category: nil) # rubocop:disable Lint/UnusedMethodArgument
          messages = messages.flatten
          return nil if messages.empty?

          Ext::Log.write(shell, :warn, messages.map { |m| m.to_s.chomp }.join("\n"))
        end

        def error(message) = Ext::Log.write(shell, :error, message)

        def debug(message)
          return nil unless Ext::Log.debug?(self)

          Ext::Log.write(shell, :debug, message)
        end
      end
    end
  end
end
