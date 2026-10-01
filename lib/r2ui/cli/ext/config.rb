# frozen_string_literal: true

# c27-config: options from a config file.
#
#   R2UI.cli "deployer" do
#     config_file "~/.deployer.yml"          # YAML, or JSON when the name ends in .json
#     option :region, default: "eu"
#     command :deploy do
#       option :replicas, :integer, default: 2
#       ...
#     end
#     command(:db) { command(:migrate) { option :steps, :integer; ... } }
#   end
#
#   # ~/.deployer.yml
#   region: us              # top-level keys: options of every command that has them
#   deploy:                 # a section per command: only that command's options
#     replicas: 4
#     dry-run: true         # dashes or underscores, like on the command line
#   db:
#     migrate:              # sections nest by command path
#       steps: 3
#
# `config_file` (on the root) adds `--config <path>` to every command, so one run can read
# another file. Before defaults and required checks, every option the command line didn't give
# is filled from the file: the nearest section wins (`deploy:` over the top level), and a value
# satisfies `required: true`. Values are converted and checked like typed input (`replicas: "4"`
# and `replicas: 4` are both 4; `in:` choices apply); `many:` options take a list or one value.
#
# What wins: the command line, then the option's environment variable (`env:`, c26), then the
# file, then the option's `default:`.
#
# A missing default file is fine (nothing is read). A missing `--config` file, a file that isn't
# YAML/JSON or isn't a mapping, a key that names no option or command anywhere in its section's
# subtree (so a typo fails whatever runs, with "Did you mean"), or a bad value is a usage error:
#
#   ✖ unknown key 'replicaz' in ~/.deployer.yml (deploy). Did you mean 'replicas'?
#   Run 'deployer deploy --help' for usage.
#
# The file is only read when a command runs, so `--help` works with a broken one. Output is the
# core's error report: styled on a terminal, plain lines off it.
module R2UI
  module CLI
    module Ext
      module ConfigFile
        module_function

        # [path to read, how to name it in messages], or nil when there's nothing to read.
        def source(context)
          declared = context.program.declared(:config_file).last
          if context.given?(:config)
            path = File.expand_path(context.options[:config].to_s)
            raise UsageError, "config file #{path} not found" unless File.file?(path)

            [path, path]
          else
            path = File.expand_path(declared)
            [path, declared] if File.file?(path)
          end
        end

        # The file's contents as a Hash ({} when empty). YAML and JSON load only when a file is read.
        def read(path, label)
          require "json"
          require "yaml"
          json = File.extname(path).casecmp?(".json")
          text = File.read(path)
          data = if text.strip.empty? then {}
                 elsif json then JSON.parse(text)
                 else YAML.safe_load(text, aliases: true)
                 end
          raise UsageError, "#{label}: expected a mapping of option names to values" unless data.nil? || data.is_a?(Hash)

          data || {}
        rescue SystemCallError => e
          raise UsageError, "can't read config file #{label}: #{e.message}"
        rescue JSON::ParserError, Psych::Exception => e
          raise UsageError, "#{label}: not valid #{json ? "JSON" : "YAML"} (#{e.message.lines.first.to_s.strip})"
        end

        def key(name) = name.to_s.tr("-", "_")

        # Options a section may set: those of its command and of every command under it.
        def settable(command)
          (command.all_options + command.commands.flat_map { |c| settable(c) }).reject { |o| o.name == :config }
        end

        # Every key in the file names an option in its section's subtree or a subcommand section.
        def validate!(section, command, label)
          names = settable(command).map { |o| o.name.to_s }.uniq
          section.each do |name, value|
            sub = command.find(name.to_s)
            next validate!(value, sub, label) if sub && value.is_a?(Hash)
            next if names.include?(key(name))

            where = command.root? ? label : "#{label} (#{command.path.drop(1).join(" ")})"
            candidates = names + names.map { |n| n.tr("_", "-") } + command.commands.flat_map { |c| [c.name, *c.aliases] }
            guess = DidYouMean::SpellChecker.new(dictionary: candidates.uniq).correct(name.to_s).first if defined?(DidYouMean)
            raise UsageError, "unknown key '#{name}' in #{where}#{". Did you mean '#{guess}'?" if guess}"
          end
        end

        # name => value for `command`: the top level, then each section down its path (a section
        # may be keyed by the command's name or an alias), so the nearest wins.
        def values_for(data, command)
          values = {}
          take = lambda do |section, owner|
            section.each { |name, value| values[key(name)] = value unless value.is_a?(Hash) && owner.find(name.to_s) }
          end
          section = data
          current = command.root
          take.call(section, current)
          command.path.drop(1).each do |name|
            parent = current
            current = parent.find(name)
            section = section.find { |k, v| v.is_a?(Hash) && parent.find(k.to_s) == current }&.last
            break unless section

            take.call(section, current)
          end
          values
        end

        def convert(option, value, label, name)
          option.many ? Array(value).map { |v| scalar(option, v) } : scalar(option, value)
        rescue UsageError => e
          raise UsageError, "#{label}: #{name} #{e.message.delete_prefix("#{option.long} ")}"
        end

        def scalar(option, value)
          raise UsageError, "expects one value" if value.is_a?(Array) || value.is_a?(Hash)

          option.convert(value.is_a?(String) ? value : value.to_s)
        end

        def env_set?(context, option)
          var = option.meta[:env]
          var && !context.shell.env[var.to_s].to_s.empty?
        end

        def fill(context)
          path, label = source(context)
          return unless path

          data = read(path, label)
          validate!(data, context.program, label)
          values = values_for(data, context.command)
          context.command.all_options.each do |option|
            next if option.name == :config || context.options.key?(option.name) || env_set?(context, option)
            next unless values.key?(option.name.to_s)

            value = values[option.name.to_s]
            context.options[option.name] = convert(option, value, label, option.name.to_s.tr("_", "-")) unless value.nil?
          end
        end
      end
    end

    extension :config do
      dsl(:command) do
        # The file whose keys fill options the command line didn't give (on the root only).
        def config_file(path)
          raise ArgumentError, "config_file belongs on the root command" unless definition.root?

          declare(:config_file, path.to_s)
        end
      end

      setup do
        file = declared(:config_file).last
        if file && !definition.option(:config)
          option :config, :path, placeholder: "path", desc: "Read options from this file (default: #{file})"
        end
      end

      after_parse { Ext::ConfigFile.fill(self) if program.declared(:config_file).any? }
    end
  end
end
