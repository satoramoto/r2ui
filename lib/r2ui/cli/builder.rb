# frozen_string_literal: true

module R2UI
  module CLI
    # The keywords inside `R2UI.cli do ... end` and `command :x do ... end`. Extensions add more
    # with `dsl(:command) { def keyword ... end }`; inside them `definition` is the Command being
    # built and `declare(key, value)` records plain data on it.
    class Builder
      attr_reader :definition

      def initialize(definition)
        @definition = definition
      end

      # One line, shown in the parent's command list and atop this command's help.
      def summary(text) = definition.summary = text

      # Longer text for this command's help (the summary when there is none).
      def description(text) = definition.description = text

      def option(name, type = :string, short: nil, default: nil, required: false, desc: nil, in: nil,
                 many: false, placeholder: nil, hidden: false, **meta)
        short = short&.to_s&.delete_prefix("-")
        raise ArgumentError, "short option must be one character, got #{short.inspect}" if short && short.size != 1

        choices = binding.local_variable_get(:in)
        definition.add_option(Option.new(name: name.to_sym, type:, short:, default:, required:, desc:, choices:,
                                         many:, placeholder:, hidden:, meta:))
      end

      # A boolean option (`--force`, `--no-force`).
      def flag(name, short: nil, default: false, desc: nil, hidden: false, **meta)
        option(name, :boolean, short:, default:, desc:, hidden:, **meta)
      end

      # A positional argument, in order. `default:` makes it optional.
      def argument(name, type = :string, required: true, many: false, desc: nil, default: nil)
        required = false unless default.nil?
        definition.add_argument(Argument.new(name: name.to_sym, type:, required:, many:, desc:, default:))
      end

      # A subcommand; its block runs on a Builder for it, so commands nest
      # (`command :db do command :migrate do ... end end`).
      def command(name, summary = nil, hidden: false, &block)
        sub = Command.new(name, parent: definition)
        sub.summary = summary
        sub.hidden = hidden
        definition.add_command(sub)
        Builder.new(sub).instance_exec(&block) if block
        sub
      end

      # Other names the command answers to (`aliases :d, :ship`).
      def aliases(*names) = definition.aliases.concat(names.map(&:to_s))

      # What the command does. The block runs on a Context: `args`, `options`, every helper.
      def run(&block)
        raise ArgumentError, "run needs a block" unless block

        definition.action = block
      end

      # Hides the command from its parent's command list (it still runs).
      def hidden = definition.hidden = true

      # For extensions: record plain data on the command (`definition.declared(key)` reads it).
      def declare(key, value) = definition.declare(key, value)

      def declared(key) = definition.declared(key)
    end
  end
end
