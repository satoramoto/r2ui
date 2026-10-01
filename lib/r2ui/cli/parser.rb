# frozen_string_literal: true

module R2UI
  module CLI
    # argv → which command, its options and arguments. Errors are UsageErrors with a "did you
    # mean" when a near name exists. Options may come anywhere after the command that owns them
    # (or an ancestor that declared them); `--` ends options.
    #
    # Parsing happens in two steps so extensions can fill options in between (the runner's
    # `after_parse` hooks): `parse` reads argv; `finish` applies defaults and checks required ones.
    class Parser
      # `options` holds the given options (converted); `given` their names.
      Invocation = Struct.new(:command, :options, :given, :args, :help, :argv, keyword_init: true)

      NEGATIVE_NUMBER = /\A-\d+(\.\d+)?\z/

      def initialize(program)
        @program = program
      end

      def parse(argv)
        argv = argv.map(&:to_s)
        command = @program
        options = {}
        positionals = []
        help = false
        only_positionals = false
        i = 0

        while i < argv.size
          token = argv[i]
          i += 1
          if only_positionals
            positionals << token
          elsif token == "--"
            only_positionals = true
          elsif %w[--help -h].include?(token)
            help = true
          elsif token.start_with?("--")
            i = long(command, token, argv, i, options)
          elsif token.start_with?("-") && token.size > 1 && !(token.match?(NEGATIVE_NUMBER) && command.arguments.any?)
            i = short(command, token, argv, i, options)
          elsif positionals.empty? && command.group? && (sub = command.find(token))
            command = sub
          elsif positionals.empty? && command.group? && token == "help" && !help
            help = true
          elsif positionals.empty? && command.group? && !(command.action && command.arguments.any?)
            raise UsageError, unknown("command", token, command.commands.reject(&:hidden).flat_map { |c| [c.name, *c.aliases] },
                                      "for '#{command.full_name}'")
          else
            positionals << token
          end
        end

        args = help ? {} : arguments(command, positionals)
        Invocation.new(command:, options:, given: options.keys, args:, help:, argv:)
      rescue UsageError => e
        e.command ||= command
        raise
      end

      # Defaults for options still missing, then required checks.
      def finish(invocation)
        options = invocation.options
        invocation.command.all_options.each do |option|
          next if options.key?(option.name)

          value = option.default_value
          if option.required && (value.nil? || value == [])
            raise UsageError, "missing required option #{option.long}"
          end

          options[option.name] = value
        end
        invocation
      end

      private

      def long(command, token, argv, i, options)
        name, value = token.delete_prefix("--").split("=", 2)
        option = find_long(command, name)
        if option.nil? && name.start_with?("no-") && value.nil?
          negated = find_long(command, name.delete_prefix("no-"))
          return store(options, negated, false, i) if negated&.boolean?
        end
        raise UsageError, unknown("option", "--#{name}", command.all_options.reject(&:hidden).map(&:long)) unless option

        if option.boolean?
          store(options, option, value.nil? ? true : option.convert(value), i)
        elsif value
          store(options, option, option.convert(value), i)
        else
          raise UsageError, "option #{option.long} needs a value" if i >= argv.size

          store(options, option, option.convert(argv[i]), i + 1)
        end
      end

      def short(command, token, argv, i, options)
        chars = token.delete_prefix("-").chars
        chars.each_with_index do |char, j|
          option = command.all_options.find { |o| o.short == char }
          raise UsageError, unknown("option", "-#{char}", command.all_options.filter_map { |o| "-#{o.short}" if o.short }) unless option
          next store(options, option, true, i) if option.boolean?

          attached = chars[(j + 1)..].join
          return store(options, option, option.convert(attached), i) unless attached.empty?
          raise UsageError, "option -#{char} (#{option.long}) needs a value" if i >= argv.size

          return store(options, option, option.convert(argv[i]), i + 1)
        end
        i
      end

      def store(options, option, value, i)
        if option.many
          (options[option.name] ||= []) << value
        else
          options[option.name] = value
        end
        i
      end

      def find_long(command, name)
        name = name.tr("-", "_")
        command.all_options.find { |o| o.name.to_s == name }
      end

      def arguments(command, positionals)
        args = {}
        command.arguments.each_with_index do |argument, index|
          if argument.many
            values = positionals[index..] || []
            raise UsageError, "missing argument #{argument.usage}" if argument.required && values.empty?

            args[argument.name] = values.empty? && argument.default ? Array(argument.default) : values.map { |v| argument.convert(v) }
          elsif index < positionals.size
            args[argument.name] = argument.convert(positionals[index])
          elsif argument.required
            raise UsageError, "missing argument #{argument.usage}"
          else
            args[argument.name] = argument.default
          end
        end
        extra = command.arguments.last&.many ? [] : positionals.drop(command.arguments.size)
        raise UsageError, "unexpected argument #{extra.first.inspect}" if extra.any?

        args
      end

      def unknown(kind, word, candidates, suffix = nil)
        message = "unknown #{kind} '#{word}'#{" #{suffix}" if suffix}"
        guess = DidYouMean::SpellChecker.new(dictionary: candidates).correct(word).first if defined?(DidYouMean)
        guess ? "#{message}. Did you mean '#{guess}'?" : message
      end
    end
  end
end
