# frozen_string_literal: true

module R2UI
  module CLI
    # The inline helpers (tasks, confirm, ...). Every extension's `helpers` block adds a module
    # here, so they are available
    # - in a command's `run` block (a Context, whose `shell` is the runner's),
    # - in any script that does `include R2UI::CLI::Helpers` (they use R2UI::CLI.shell),
    # - as `R2UI::CLI.confirm(...)` and friends.
    #
    # A helper writes only through `shell` (Shell#puts, #err_puts, #paint, #symbol), so it works on
    # a terminal, in a pipe and in tests alike.
    module Helpers
      def shell = CLI.shell

      # Prints a line, styled with theme styles when the shell has colour: `say "Done", :success`.
      def say(text = "", *styles) = shell.puts(shell.paint(text, *styles))
    end
  end
end
