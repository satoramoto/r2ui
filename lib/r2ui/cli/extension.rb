# frozen_string_literal: true

module R2UI
  module CLI
    # One CLI capability in one file, the same shape as the dashboard DSL's R2UI.extension
    # (docs/dsl.md). Files in lib/r2ui/cli/ext/ load automatically, in name order. See docs/cli.md
    # and the reference ones, lib/r2ui/cli/ext/tasks.rb and confirm.rb.
    #
    #   R2UI::CLI.extension :version do
    #     dsl(:command) { def version(v) = declare(:version, v) }
    #     setup { flag :version, short: "V", desc: "Print the version" if declared(:version).any? }
    #     before_run { (say(program.declared(:version).last) || halt) if options[:version] }
    #   end
    #
    #   dsl(:command) { def kw ... end }   keywords on Builder (`definition`, `declare`), at definition
    #   helpers { def h ... end }          methods on Helpers (so on every Context too)
    #   setup { }                          on the root's Builder, after the R2UI.cli block
    #   after_parse { }                    on the Context, argv parsed, before defaults, required
    #                                      checks and positional arguments (`args` is empty here)
    #   before_run { }                     on the Context, before the command's run block
    #   after_run { }                      on the Context, after it returned normally
    #   help_header { |command, shell| }   returns a String (or nil) shown first in --help
    #   help_section { |command, shell| }  returns [heading, lines] (or nil) to append to --help
    #   on_error(Klass) { |error| }        on the Context when an error escapes; returning an Integer
    #                                      makes it the exit code and skips the core's report
    class Extension
      TARGETS = { command: -> { Builder } }.freeze

      Hook = Data.define(:extension, :matcher, :order, :block) do
        def match?(value) = matcher.nil? || matcher === value # rubocop:disable Style/CaseEquality
      end

      attr_reader :name, :hooks

      def initialize(name)
        @name = name.to_sym
        @modules = []
        @hooks = Hash.new { |h, k| h[k] = [] }
      end

      def dsl(target = :command, &body)
        builder = TARGETS.fetch(target) { raise Error, "unknown DSL target #{target.inspect}" }.call
        add_module(builder, Module.new(&body))
      end

      def helpers(&body) = add_module(Helpers, Module.new(&body), also: Context)

      def setup(&block) = hook(:setup, nil, block)

      def after_parse(&block) = hook(:after_parse, nil, block)

      def before_run(&block) = hook(:before_run, nil, block)

      def after_run(&block) = hook(:after_run, nil, block)

      def help_section(&block) = hook(:help_section, nil, block)

      def help_header(&block) = hook(:help_header, nil, block)

      def on_error(matcher = StandardError, &block) = hook(:on_error, matcher, block)

      def remove!
        @modules.each do |mod|
          (mod.instance_methods(false) + mod.private_instance_methods(false)).each { |m| mod.send(:remove_method, m) }
        end
        @hooks.clear
      end

      private

      def hook(kind, matcher, block)
        raise ArgumentError, "#{kind} needs a block" unless block

        @hooks[kind] << Hook.new(extension: name, matcher:, order: Extensions.next_order, block:)
      end

      def add_module(target, mod, also: nil)
        defined = mod.instance_methods(false) + mod.private_instance_methods(false)
        taken = defined.select do |m|
          [target, also].compact.any? { |t| t.method_defined?(m) || t.private_method_defined?(m) && t.instance_method(m).owner != Kernel }
        end
        raise Error, "extension #{name}: #{target} already has #{taken.join(", ")}" if taken.any?

        target.include(mod)
        @modules << mod
        mod
      end
    end

    # The loaded CLI extensions, in load order.
    module Extensions
      @all = {}
      @order = 0
      @lock = Mutex.new

      class << self
        def register(name, &block)
          name = name.to_sym
          raise Error, "CLI extension #{name} is already registered" if @all.key?(name)

          extension = Extension.new(name)
          @all[name] = extension
          begin
            extension.instance_eval(&block) if block
          rescue StandardError
            remove(name)
            raise
          end
          extension
        end

        def [](name) = @all[name.to_sym]

        def names = @all.keys

        # Unregisters an extension and empties its modules (for tests).
        def remove(name) = @all.delete(name.to_sym)&.remove!

        def hooks(kind) = @all.values.flat_map { |e| e.hooks.fetch(kind, []) }.sort_by(&:order)

        def next_order = @lock.synchronize { @order += 1 }

        def load_all(dir = File.expand_path("ext", __dir__))
          Dir[File.join(dir, "*.rb")].sort.each { |file| require file }
        end
      end
    end
  end
end
