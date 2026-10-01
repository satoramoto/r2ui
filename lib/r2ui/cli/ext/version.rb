# frozen_string_literal: true

# c23-version: `tool --version`.
#
#   R2UI.cli "deployer" do
#     version "1.4.0"            # or Deployer::VERSION
#     ...
#   end
#
#   $ deployer --version         # or -V, or `deployer deploy --version`
#   deployer 1.4.0
#
# `version` on the root adds `-V, --version` ("Print the version") to every command. The flag
# prints "<name> <version>" on stdout and exits 0 before anything else is checked: missing
# required options or arguments don't matter and no command runs. The root's `--help` starts with
# the same line.
#
# On a colour terminal the name is bold and the version in the accent colour; in a pipe it is the
# plain line, so `deployer --version | cut -d' ' -f2` is stable.
#
# A tool that already has a `-V` keeps it (the flag is then `--version` only); one that defines
# its own `version` option keeps that too, and only the help line is added.
module R2UI
  module CLI
    module Ext
      module VersionFlag
        module_function

        def line(shell, program)
          version = program.declared(:version).last
          "#{shell.paint(program.name, :heading)} #{shell.paint(version.to_s, :accent)}"
        end

        # True when --version is the flag this extension added (not the tool's own option).
        def ours?(option) = option&.meta&.fetch(:r2ui_version_flag, false)
      end
    end

    extension :version do
      dsl(:command) do
        def version(value)
          raise ArgumentError, "#{definition.full_name}: version belongs on the root command" unless definition.root?

          declare(:version, value)
        end
      end

      setup do
        next if declared(:version).empty? || definition.option(:version)

        short = definition.options.any? { |o| o.short == "V" } ? nil : "V"
        flag :version, short:, desc: "Print the version", r2ui_version_flag: true
      end

      after_parse do
        next unless options[:version] && Ext::VersionFlag.ours?(command.option(:version))

        shell.puts(Ext::VersionFlag.line(shell, program))
        halt(0)
      end

      help_header do |command, shell|
        Ext::VersionFlag.line(shell, command) if command.root? && command.declared(:version).any?
      end
    end
  end
end
