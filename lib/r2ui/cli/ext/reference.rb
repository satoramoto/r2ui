# frozen_string_literal: true

# c30-reference: a Markdown reference for the whole tool, for a README or a docs site.
#
#   R2UI.cli "deployer" do
#     reference_command              # adds a hidden `deployer reference`
#     # reference_command :docs      # ... or under another name
#     command(:deploy, "Deploy an app") { argument :app; option :env, default: "staging"; run { ... } }
#   end
#
#   deployer reference > docs/cli-reference.md
#
# prints, for the root and every visible command under it (depth first, in definition order), a
# heading by its path (`#` for the root, `##` one level down, ...), its summary and description,
# its aliases, its usage in a code block, and Markdown tables of its arguments and its options
# (inherited ones too, as --help shows them; hidden commands and options are left out, and so is
# the reference command itself):
#
#   ## deployer deploy
#
#   Deploy an app
#
#   ```
#   deployer deploy <app> [options]
#   ```
#
#   | Option | Description |
#   |---|---|
#   | `--env <env>` | (default: staging) |
#
# The text depends only on the definition, so it's the same on every run and in every
# environment: piped or redirected it is plain Markdown. On a terminal with colour the same text
# has its headings and names styled for reading; strip the escapes and it's byte-identical.
module R2UI
  module CLI
    module Ext
      module Reference
        # Help#usage paints through a shell; this one leaves the text plain.
        PLAIN = Object.new
        def PLAIN.paint(text, *) = text.to_s

        module_function

        def markdown(program, shell, skip: nil)
          visible(program, skip).map { |command| section(command, shell) }.join("\n")
        end

        # The root and its visible subtree, depth first.
        def visible(command, skip)
          children = command.commands.reject { |c| c.hidden || c.equal?(skip) }
          [command, *children.flat_map { |c| visible(c, skip) }]
        end

        def section(command, shell)
          level = [command.path.size, 6].min
          blocks = [shell.paint("#{"#" * level} #{command.full_name}", :heading)]
          blocks << inline(command.summary) if present?(command.summary)
          blocks << command.description.to_s.strip if present?(command.description) && command.description != command.summary
          blocks << "Aliases: #{command.aliases.map { |a| code(a, shell) }.join(", ")}" if command.aliases.any?
          blocks << "```\n#{shell.paint(Help.new(command, PLAIN).usage, :accent)}\n```"
          blocks << table("Argument", command.arguments.map { |a| [a.name.to_s.tr("_", "-"), argument_text(a)] }, shell)
          blocks << table("Option", command.all_options.reject(&:hidden).map { |o| [label(o), option_text(o)] }, shell)
          "#{blocks.compact.join("\n\n")}\n"
        end

        def table(heading, rows, shell)
          return nil if rows.empty?

          lines = ["| #{heading} | Description |", "|---|---|"]
          rows.each { |name, text| lines << "| #{code(name, shell)} | #{cell(text)} |" }
          lines.join("\n")
        end

        def label(option)
          long = option.boolean? && option.default == true ? "--[no-]#{option.long.delete_prefix("--")}" : option.long
          long += " <#{option.value_name}>" unless option.boolean?
          long += "..." if option.many
          option.short ? "-#{option.short}, #{long}" : long
        end

        def option_text(option)
          notes = []
          notes << option.choices.join(", ") if option.choices
          notes << "required" if option.required
          default = option.default
          notes << "default: #{default}" if !default.nil? && !default.respond_to?(:call) && default != false && default != []
          [option.desc, notes.empty? ? nil : "(#{notes.join("; ")})"].compact.join(" ")
        end

        def argument_text(argument)
          notes = []
          notes << "default: #{argument.default}" unless argument.default.nil?
          notes << "optional" unless argument.required
          notes << "one or more" if argument.many && argument.required
          [argument.desc, notes.empty? ? nil : "(#{notes.join("; ")})"].compact.join(" ")
        end

        def code(text, shell) = shell.paint("`#{text}`", :accent)

        # One table cell: one line, pipes escaped.
        def cell(text) = inline(text).gsub("|", "\\|")

        def inline(text) = text.to_s.split.join(" ")

        def present?(text) = !text.nil? && !text.to_s.strip.empty?
      end
    end

    extension :reference do
      dsl(:command) do
        # Adds a hidden command (`reference` unless named) printing the tool's Markdown reference.
        def reference_command(name = :reference)
          raise ArgumentError, "reference_command goes on the root, not on #{definition.full_name}" unless definition.root?

          declare(:reference_command, name.to_sym)
        end
      end

      setup do
        name = declared(:reference_command).last
        if name
          command(name, "Print a Markdown reference for every command", hidden: true) do
            run { shell.print(Ext::Reference.markdown(program, shell, skip: command)) }
          end
        end
      end
    end
  end
end
