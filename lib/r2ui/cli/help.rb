# frozen_string_literal: true

module R2UI
  module CLI
    # The generated `--help` for a command:
    #
    #   Deploy an app to the fleet
    #
    #   Usage
    #     deployer deploy <app> [sha] [options]
    #
    #   Arguments
    #     app   App to deploy
    #
    #   Options
    #     -e, --env <env>   Target environment (staging, production) [default: staging]
    #         --[no-]force  Skip the checks
    #     -h, --help        Show help
    #
    # The first line is the command's summary; a description follows it after a blank line (with
    # only one of them, that one).
    #
    # Headings bold, names in the accent colour, defaults muted, when the shell has colour; the
    # same text without escapes otherwise. Extensions put lines on top with `help_header` (e.g.
    # "deployer 1.4.0") and append sections with `help_section`.
    class Help
      INDENT = "  "
      GAP = "  "

      def initialize(command, shell)
        @command = command
        @shell = shell
      end

      def to_s
        sections = Extensions.hooks(:help_header).filter_map do |hook|
          text = hook.block.call(@command, @shell)
          text.nil? || text.to_s.empty? ? nil : text.to_s.chomp
        end
        sections.concat([@command.summary, @command.description].compact.map { |text| text.to_s.chomp }.uniq)
        sections << section("Usage", [INDENT + usage])
        sections << table("Arguments", @command.arguments.map { |a| [a.name.to_s.tr("_", "-"), describe_argument(a)] })
        sections << table("Commands", visible_commands.map { |c| [[c.name, *c.aliases].join(", "), c.summary.to_s] })
        sections << table("Options", option_rows)
        Extensions.hooks(:help_section).each do |hook|
          heading, body = hook.block.call(@command, @shell)
          sections << section(heading, Array(body).flat_map { |b| b.to_s.split("\n") }.map { |l| INDENT + l }) if heading
        end
        sections << footer if @command.group?
        "#{sections.compact.join("\n\n")}\n"
      end

      def usage
        parts = [@command.full_name]
        parts << "<command>" if @command.group? && !@command.action
        parts << "[command]" if @command.group? && @command.action
        parts.concat(@command.arguments.map(&:usage))
        parts << "[options]"
        @shell.paint(parts.join(" "), :accent)
      end

      private

      def visible_commands = @command.commands.reject(&:hidden)

      def option_rows
        options = @command.all_options.reject(&:hidden)
        rows = options.map { |o| [option_label(o), describe_option(o)] }
        rows << ["-h, --help", "Show help"]
        rows
      end

      def option_label(option)
        short = option.short ? "-#{option.short}, " : "    "
        long = option.boolean? && option.default == true ? "--[no-]#{option.long.delete_prefix("--")}" : option.long
        long += " <#{option.value_name}>" unless option.boolean?
        long += "..." if option.many
        short + long
      end

      def describe_option(option)
        notes = []
        notes << option.choices.join(", ") if option.choices
        notes << "required" if option.required
        default = option.default
        notes << "default: #{default}" if !default.nil? && !default.respond_to?(:call) && default != false && default != []
        [option.desc, notes.empty? ? nil : @shell.paint("(#{notes.join("; ")})", :muted)].compact.join(" ")
      end

      def describe_argument(argument)
        notes = argument.default.nil? ? nil : @shell.paint("(default: #{argument.default})", :muted)
        [argument.desc, notes].compact.join(" ")
      end

      def section(heading, lines)
        return nil if lines.empty?

        [@shell.paint(heading, :heading), *lines].join("\n")
      end

      def table(heading, rows)
        return nil if rows.empty?

        width = rows.map { |name, _| name.size }.max
        lines = rows.map do |name, text|
          line = INDENT + @shell.paint(name, :accent)
          text.to_s.empty? ? line : line + (" " * (width - name.size)) + GAP + text
        end
        section(heading, lines)
      end

      def footer
        @shell.paint("Run '#{@command.full_name} <command> --help' for more about a command.", :muted)
      end
    end
  end
end
