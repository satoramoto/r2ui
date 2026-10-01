# frozen_string_literal: true

module R2UI
  module CLI
    # Value types for options and arguments: a Symbol from TYPES, or anything with #call that
    # turns the string into a value (raising ArgumentError/TypeError for a bad one).
    TYPES = {
      string: ->(s) { s },
      integer: ->(s) { Integer(s, 10) },
      float: ->(s) { Float(s) },
      boolean: ->(s) { Option.boolean(s) },
      path: ->(s) { File.expand_path(s) }
    }.freeze

    # A typed option. `--name value`, `--name=value`, `-n value`, `-nvalue`; booleans are
    # `--name` / `--no-name` and cluster (`-vf`). `many: true` collects repeats into an Array.
    # `default:` may be a lambda (called when the option isn't given: `-> { ENV["TOKEN"] }`).
    # `meta` keeps any other keyword, for extensions (`option :token, secret: true`).
    Option = Data.define(:name, :type, :short, :default, :required, :desc, :choices, :many,
                         :placeholder, :hidden, :meta) do
      def self.boolean(string)
        case string.to_s.downcase
        when "true", "yes", "y", "1", "on" then true
        when "false", "no", "n", "0", "off" then false
        else raise ArgumentError, "expects true or false"
        end
      end

      def long = "--#{name.to_s.tr("_", "-")}"

      def boolean? = type == :boolean

      # The value name in help: `--env <env>`.
      def value_name = placeholder || name.to_s.tr("_", "-")

      def convert(string)
        value = CLI.convert(type, string)
        if choices && !choices.include?(value)
          raise UsageError, "#{long} must be one of #{choices.join(", ")} (got #{string.inspect})"
        end

        value
      rescue ArgumentError, TypeError => e
        raise UsageError, "#{long} #{type_error(e)}, got #{string.inspect}"
      end

      def default_value
        value = default.respond_to?(:call) ? default.call : default
        value = convert(value) if value.is_a?(String) && type != :string
        many && value.nil? ? [] : value.dup
      end

      private

      def type_error(error)
        type.is_a?(Symbol) && type != :boolean ? "expects #{type == :integer ? "an" : "a"} #{type}" : error.message
      end
    end

    # A positional argument. `many: true` (the last one only) takes the rest as an Array.
    Argument = Data.define(:name, :type, :required, :many, :desc, :default) do
      def usage
        base = "#{name.to_s.tr("_", "-")}#{"..." if many}"
        required ? "<#{base}>" : "[#{base}]"
      end

      def convert(string)
        CLI.convert(type, string)
      rescue ArgumentError, TypeError
        raise UsageError, "<#{name}> expects #{type == :integer ? "an" : "a"} #{type}, got #{string.inspect}"
      end
    end

    def self.convert(type, string)
      converter = type.respond_to?(:call) ? type : TYPES.fetch(type) { raise ArgumentError, "unknown type #{type.inspect}" }
      converter.call(string)
    end

    # One command: the root (the Program) or a subcommand. Plain data, built by Builder; nothing
    # here parses or prints. `declared(key)` holds what extension keywords recorded.
    class Command
      attr_reader :name, :parent, :options, :arguments, :commands, :aliases, :declarations
      attr_accessor :summary, :description, :action, :hidden

      def initialize(name, parent: nil)
        @name = name.to_s
        @parent = parent
        @options = []
        @arguments = []
        @commands = []
        @aliases = []
        @declarations = Hash.new { |h, k| h[k] = [] }
        @hidden = false
      end

      def root? = parent.nil?

      def root = root? ? self : parent.root

      def group? = commands.any?

      # ["deployer", "db", "migrate"]
      def path = root? ? [name] : parent.path + [name]

      def full_name = path.join(" ")

      def declare(key, value)
        @declarations[key.to_sym] << value
        value
      end

      def declared(key) = @declarations.fetch(key.to_sym, [])

      # The subcommand called `name` (or aliased so).
      def find(name)
        name = name.to_s
        commands.find { |c| c.name == name || c.aliases.include?(name) }
      end

      # Options this command accepts: its own, then its ancestors' (a group's options apply to
      # its whole subtree), nearest first.
      def all_options = options + (root? ? [] : parent.all_options)

      def option(name) = all_options.find { |o| o.name == name.to_sym }

      def add_option(option)
        taken = all_options.find { |o| o.name == option.name || (option.short && o.short == option.short) }
        raise ArgumentError, "#{full_name}: option #{option.long} clashes with #{taken.long}" if taken
        raise ArgumentError, "#{full_name}: -h is reserved for --help" if option.short == "h" || option.name == :help

        @options << option
        option
      end

      def add_argument(argument)
        raise ArgumentError, "#{full_name}: only the last argument can be many: true" if arguments.last&.many
        if argument.required && arguments.any? { |a| !a.required }
          raise ArgumentError, "#{full_name}: required argument <#{argument.name}> after an optional one"
        end

        @arguments << argument
        argument
      end

      def add_command(command)
        raise ArgumentError, "#{full_name}: command #{command.name} is defined twice" if find(command.name)

        @commands << command
        command
      end

      def inspect = "#<#{self.class.name} #{full_name}>"
    end

    # The root command of a tool, plus how to run it.
    class Program < Command
      def self.build(name, &block)
        program = new(name)
        builder = Builder.new(program)
        builder.instance_exec(&block) if block
        Extensions.hooks(:setup).each { |hook| builder.instance_exec(&hook.block) }
        program
      end

      # Runs argv and returns the exit code. Tests call this with a Shell on StringIOs.
      def call(argv = ARGV, shell: CLI.shell) = Runner.new(self, shell:).call(argv)

      # Runs argv and exits the process with the code.
      def start(argv = ARGV, shell: CLI.shell) = exit(call(argv, shell:))
    end
  end
end

require_relative "builder"
