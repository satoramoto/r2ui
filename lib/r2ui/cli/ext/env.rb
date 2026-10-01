# frozen_string_literal: true

# c26-env: options from environment variables.
#
#   R2UI.cli "deployer" do
#     option :token, env: "DEPLOY_TOKEN", required: true, desc: "API token"
#     option :port, :integer, env: "DEPLOY_PORT", default: 80
#     option :env, env: %w[DEPLOY_ENV RACK_ENV]       # the first one set wins
#     option :tags, many: true, env: "DEPLOY_TAGS"    # "web,api" => ["web", "api"]
#     flag :force, env: "DEPLOY_FORCE"                # 1/0, true/false, yes/no, on/off
#   end
#
#   $ DEPLOY_TOKEN=s3cret deployer            # options[:token] == "s3cret"
#   $ DEPLOY_TOKEN=s3cret deployer --token x  # the command line wins: "x"
#
# When an option isn't on the command line, its variable fills it (in `after_parse`, so before
# defaults and the required check: a set variable satisfies `required: true`, and a default
# lambda isn't called). The value is converted and checked like typed input (type, `in:`), and a
# bad one is a usage error that names the variable:
#
#   ✖ DEPLOY_PORT: --port expects an integer, got "eighty"
#   Run 'deployer --help' for usage.
#
# An empty variable counts as unset. `given?(:token)` stays false: it means typed. Options from
# a group apply to its subcommands, variables included. Variables are read from the shell's env
# (`Shell#env`, ENV by default), so tests pass `env:` to `run_cli`.
#
# `--help` gains an "Environment" section (hidden options left out), names in the accent colour
# and headings bold on a terminal, plain text in a pipe:
#
#   Environment
#     DEPLOY_TOKEN  --token
#     DEPLOY_PORT   --port
#     DEPLOY_TAGS   --tags (comma-separated)
module R2UI
  module CLI
    module Ext
      module EnvOptions
        module_function

        # The variable names for an option (none when it has no `env:`).
        def names(option) = Array(option.meta[:env])

        def check!(command)
          command.options.each do |option|
            env = option.meta[:env]
            next if env.nil?

            valid = Array(env).then { |list| list.any? && list.all? { |n| n.is_a?(String) && !n.empty? } }
            raise ArgumentError, "#{command.full_name}: #{option.long} env: expects a variable name or a list of them, got #{env.inspect}" unless valid
          end
          command.commands.each { |sub| check!(sub) }
        end

        # The first set (non-empty) variable as [name, raw value], or nil.
        def lookup(option, env)
          names(option).each do |name|
            value = env[name]
            return [name, value] unless value.nil? || value.empty?
          end
          nil
        end

        def convert(option, name, raw)
          if option.many
            raw.split(",").map(&:strip).reject(&:empty?).map { |part| option.convert(part) }
          else
            option.convert(raw)
          end
        rescue UsageError => e
          raise UsageError, "#{name}: #{e.message}"
        end

        def help(command, shell)
          rows = command.all_options.reject(&:hidden).flat_map do |option|
            names(option).map { |name| [name, option] }
          end
          return nil if rows.empty?

          width = rows.map { |name, _| name.size }.max
          lines = rows.map do |name, option|
            note = option.many ? " #{shell.paint("(comma-separated)", :muted)}" : ""
            "#{shell.paint(name, :accent)}#{" " * (width - name.size)}  #{option.long}#{note}"
          end
          ["Environment", lines]
        end
      end
    end

    extension :env do
      setup { Ext::EnvOptions.check!(definition) }

      after_parse do
        command.all_options.each do |option|
          next if given?(option.name)

          name, raw = Ext::EnvOptions.lookup(option, shell.env)
          next unless name

          value = Ext::EnvOptions.convert(option, name, raw)
          options[option.name] = value unless option.many && value.empty?
        end
      end

      help_section { |command, shell| Ext::EnvOptions.help(command, shell) }
    end
  end
end
