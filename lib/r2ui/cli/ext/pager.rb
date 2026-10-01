# frozen_string_literal: true

require "shellwords"

# c12-pager: show long output in a pager, the way git log and gh do.
#
#   pager(changelog)                       # => nil
#   pager(rows.map { |r| format(r) }.join("\n"))
#
# On a terminal (Shell#interactive?), when the text is taller than the screen (wrapped lines count
# by their rows at the shell width), it is piped through `$PAGER`, or `less -R -F -X` when that is
# unset: -R keeps colours, -F quits at once if it fits after all, -X leaves the text in the
# scrollback. `pager` waits for the pager to exit. ctrl+c belongs to the pager while it runs (the
# tool ignores SIGINT until it exits, like git), and the previous SIGINT handler is put back on
# every path; nothing else about the terminal is touched, so there is nothing else to restore.
# Quitting the pager before the end of the text is fine.
#
# Otherwise it prints the text through the shell, unchanged, with a final newline: in a pipe or CI
# (`tool log | grep fix`), with `TERM=dumb`, when the text fits on the screen, when `$PAGER` is
# empty or `cat`, inside a live region (it prints above it), and when the pager program can't be
# started (not installed: it falls back to printing, no error).
#
# `$PAGER` is split like a shell would split it (`PAGER="less -S"`, quotes allowed) and run
# without a shell.
module R2UI
  module CLI
    module Ext
      module Pager
        DEFAULT = "less -R -F -X"

        module_function

        def show(shell, text)
          text = text.to_s
          return if text.empty?

          text = "#{text}\n" unless text.end_with?("\n")
          return if page?(shell, text) && run(shell, command(shell), text)

          shell.puts(text.chomp) # above a live region while one draws
        end

        def page?(shell, text) = !shell.live && shell.interactive? && rows(text, shell.width) > shell.height

        # $PAGER split into words; nil when it means "don't page" (empty, `cat`, unbalanced quotes).
        def command(shell)
          words = Shellwords.split(shell.env["PAGER"] || DEFAULT)
          words unless words.empty? || words == ["cat"]
        rescue ArgumentError
          nil
        end

        # Screen rows the text takes at `width` columns.
        def rows(text, width)
          text.split("\n").sum { |line| [(Lipgloss.width(line) + width - 1) / width, 1].max }
        end

        # Runs the pager with the text on its stdin and waits for it. False when it couldn't start.
        def run(shell, command, text)
          return false unless command

          reader, writer = IO.pipe
          begin
            pid = Process.spawn(shell.env.to_h, [command.first, command.first], *command.drop(1),
                                in: reader, out: shell.output, err: shell.error)
          rescue SystemCallError, TypeError, ArgumentError # not installed, or IOs without a descriptor
            return false
          ensure
            reader.close
          end
          previous = trap("INT", "IGNORE")
          begin
            writer.write(text)
          rescue Errno::EPIPE
            nil # quit before the end
          ensure
            writer.close
            Process.wait(pid)
            trap("INT", previous)
          end
          true
        ensure
          writer.close unless writer.nil? || writer.closed?
        end
      end
    end

    extension :pager do
      helpers do
        def pager(text)
          Ext::Pager.show(shell, text)
          nil
        end
      end
    end
  end
end
