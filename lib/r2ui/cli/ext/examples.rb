# frozen_string_literal: true

# c29-examples: example invocations in a command's --help.
#
#   R2UI.cli "deployer" do
#     command :deploy do
#       example "deployer deploy api -e production", "Deploy api to production"
#       example "deployer deploy web"                   # the description is optional
#     end
#   end
#
# `example(command_line, description = nil)` is repeatable and works on the root and on any
# command; each command's help shows only its own examples, in the order given, as a last
# section after Options:
#
#   Examples
#     # Deploy api to production
#     deployer deploy api -e production
#     deployer deploy web
#
# On a terminal the "# ..." comment is muted and the command is in the accent colour (the same
# colour as the Usage line), so the runnable part stands out. Off a terminal (a pipe, CI,
# NO_COLOR) it is the same text without escape codes. A multi-line description makes several
# comment lines. The command line is printed as given (no "$ " prompt), so it copies cleanly.
module R2UI
  module CLI
    module Ext
      module Examples
        Example = Data.define(:command_line, :description)

        module_function

        def section(command, shell)
          examples = command.declared(:example)
          return nil if examples.empty?

          ["Examples", examples.flat_map { |e| lines(e, shell) }]
        end

        def lines(example, shell)
          comments = example.description.to_s.split("\n").map { |line| shell.paint("# #{line}".rstrip, :muted) }
          commands = example.command_line.split("\n").map { |line| shell.paint(line, :accent) }
          comments + commands
        end
      end
    end

    extension :examples do
      dsl(:command) do
        def example(command_line, description = nil)
          command_line = command_line.to_s.strip
          raise ArgumentError, "example needs a command line" if command_line.empty?

          description = description&.to_s&.strip
          declare(:example, Ext::Examples::Example.new(command_line:, description:))
        end
      end

      help_section { |command, shell| Ext::Examples.section(command, shell) }
    end
  end
end
