# frozen_string_literal: true

# c24-completion: shell completion scripts, generated from the command tree.
#
#   R2UI.cli "deployer" do
#     completion                      # adds `deployer completion <bash|zsh|fish>`
#     command :deploy do
#       aliases :d
#       option :env, short: "e", in: %w[staging production]
#     end
#   end
#
# `deployer completion bash` (or zsh, fish) prints a static script that completes, at every level
# of the tree, the commands and their aliases, the options a command accepts (its own and its
# groups', `--no-x` for default-true flags, `--help`) and the `in:` choices of an option's value
# (`--env <TAB>`, `-e <TAB>`, `--env=<TAB>`); `:path` options complete files. Hidden commands and
# options are left out. zsh and fish show each command's summary and each option's `desc:`.
#
#   eval "$(deployer completion bash)"            # in ~/.bashrc
#   eval "$(deployer completion zsh)"             # in ~/.zshrc, after compinit
#   deployer completion fish | source             # in ~/.config/fish/config.fish
#
# `deployer completion --help` shows those lines. The script is plain text on a terminal and off
# it alike (it's data); on a terminal a hint on stderr says how to load it. An unknown shell is a
# usage error with a "did you mean".
module R2UI
  module CLI
    module Ext
      module Completion
        SHELLS = { "bash" => "Bourne Again SHell", "zsh" => "Z shell", "fish" => "Friendly interactive shell" }.freeze
        SETUP = {
          "bash" => ['eval "$(%s completion bash)"', "in ~/.bashrc"],
          "zsh" => ['eval "$(%s completion zsh)"', "in ~/.zshrc, after compinit"],
          "fish" => ["%s completion fish | source", "in ~/.config/fish/config.fish"]
        }.freeze
        HELP = { long: "--help", short: "-h", negation: nil, desc: "Show help", value: false, choices: nil, path: false }.freeze

        # One command the completion knows: its number in the script, the words that may follow it
        # (subcommands and aliases, or the completion command's shells) and the options it takes.
        Node = Struct.new(:id, :command, :words, :options)

        # The visible tree as numbered nodes and links ("from word" → to).
        class Tree
          attr_reader :nodes, :links

          def initialize(program)
            @nodes = []
            @links = []
            add(program)
          end

          private

          def add(command)
            node = Node.new(@nodes.size, command, [], options(command))
            @nodes << node
            if command.declared(:completion_command).any?
              node.words = SHELLS.to_a
              return node
            end

            visible = command.commands.reject(&:hidden)
            visible.each do |sub|
              child = add(sub)
              [sub.name, *sub.aliases].each do |word|
                node.words << [word, sub.summary]
                @links << [node.id, word, child.id]
              end
            end
            # `tool help deploy`: offered at the root only (like cobra), understood in every group.
            if visible.any? && !command.find("help")
              node.words << ["help", "Show help for a command"] if command.root?
              @links << [node.id, "help", node.id]
            end
            node
          end

          def options(command)
            command.all_options.reject(&:hidden).map do |o|
              negation = o.boolean? && o.default == true ? "--no-#{o.long.delete_prefix("--")}" : nil
              { long: o.long, short: o.short && "-#{o.short}", negation:, desc: o.desc, value: !o.boolean?,
                choices: o.choices&.map(&:to_s), path: o.type == :path }
            end + [HELP]
          end
        end

        module_function

        def script(program, kind)
          Script.new(program).public_send(kind)
        end

        def unknown(kind)
          message = "unknown shell '#{kind}' (expected #{SHELLS.keys[0..-2].join(", ")} or #{SHELLS.keys.last})"
          guess = DidYouMean::SpellChecker.new(dictionary: SHELLS.keys).correct(kind).first if defined?(DidYouMean)
          guess ||= near(kind.to_s.downcase)
          guess ? "#{message}. Did you mean '#{guess}'?" : message
        end

        # DidYouMean's threshold is too strict for 3-4 letter words (`zhs`, `bsah`, `fsih`): a
        # shell with the same letters, one edit away (words up to 4 letters), or one swap away.
        def near(word)
          SHELLS.keys.find { |name| name.chars.sort == word.chars.sort } ||
            SHELLS.keys.find { |name| word.size <= 4 && distance(word, name) <= 1 } ||
            SHELLS.keys.find { |name| transposition?(word, name) }
        end

        def transposition?(a, b)
          return false unless a.size == b.size

          diff = (0...a.size).reject { |i| a[i] == b[i] }
          diff.size == 2 && diff[1] == diff[0] + 1 && a[diff[0]] == b[diff[1]] && a[diff[1]] == b[diff[0]]
        end

        # Levenshtein distance.
        def distance(a, b)
          row = (0..b.size).to_a
          a.each_char.with_index(1) do |ca, i|
            previous = row.dup
            row[0] = i
            b.each_char.with_index(1) do |cb, j|
              row[j] = [previous[j] + 1, row[j - 1] + 1, previous[j - 1] + (ca == cb ? 0 : 1)].min
            end
          end
          row[b.size]
        end

        def setup_lines(shell, name)
          rows = SETUP.map { |kind, (line, where)| [kind, format(line, name), where] }
          kind_width = rows.map { |r| r[0].size }.max
          line_width = rows.map { |r| r[1].size }.max
          rows.map do |kind, line, where|
            "#{kind.ljust(kind_width)}  #{shell.paint(line, :accent)}#{" " * (line_width - line.size)}  #{shell.paint(where, :muted)}"
          end
        end

        # The three scripts. Every table is a `case` on node numbers, so names never become
        # code; words are single-quoted, and choices also backslash-escaped for the shells that
        # expand them.
        class Script
          def initialize(program)
            @name = program.name
            @id = program.name.gsub(/[^A-Za-z0-9_]/, "_")
            @tree = Tree.new(program)
          end

          def bash
            <<~BASH
              # bash completion for #{@name}
              # Generated by `#{@name} completion bash`; regenerate it when the tool changes.
              # Load it in this shell:  eval "$(#{@name} completion bash)"
              # For every new shell, add that line to ~/.bashrc.

              #{next_function}

              #{takes_value_function}

              __#{@id}_complete_choices() {
                case "$1 $2" in
              #{indent(choice_cases { |words| "REPLY=#{sq(words.map { |w| escape(w) }.join(" "))}" }, 4)}
                  *) return 1 ;;
                esac
              }

              __#{@id}_complete_options() {
                case "$1" in
              #{indent(@tree.nodes.map { |n| "#{n.id}) REPLY=#{sq(option_words(n).join(" "))} ;;  # #{n.command.full_name}" }, 4)}
                  *) return 1 ;;
                esac
              }

              __#{@id}_complete_words() {
                case "$1" in
              #{indent(word_nodes.map { |n| "#{n.id}) REPLY=#{sq(n.words.map { |w, _| escape(w) }.join(" "))} ;;  # #{n.command.full_name}" }, 4)}
                  *) return 1 ;;
                esac
              }

              _#{@id}() {
                local line=${COMP_LINE:0:COMP_POINT} node=0 word cur skip= positional= REPLY i
                local -a words
                read -ra words <<< "$line"
                [[ -z $line || $line == *[[:space:]] ]] && words+=("")
                cur=${words[${#words[@]}-1]}
                COMPREPLY=()
                for ((i = 1; i < ${#words[@]} - 1; i++)); do
                  word=${words[i]}
                  if [[ -n $skip ]]; then skip=; continue; fi
                  case $word in
                    --) return 0 ;;
                    --*=*) ;;
                    --*) __#{@id}_complete_takes_value "$node" "$word" && skip=$word ;;
                    -?*) __#{@id}_complete_takes_value "$node" "-${word: -1}" && skip="-${word: -1}" ;;
                    *)
                      if [[ -z $positional ]] && __#{@id}_complete_next "$node $word"; then node=$REPLY; else positional=1; fi ;;
                  esac
                done
                if [[ -n $skip ]]; then
                  __#{@id}_complete_choices "$node" "$skip" && COMPREPLY=($(compgen -W "$REPLY" -- "$cur"))
                  return 0
                fi
                if [[ $cur == --*=* ]]; then
                  local prefix=
                  [[ $COMP_WORDBREAKS == *=* ]] || prefix="${cur%%=*}="
                  __#{@id}_complete_choices "$node" "${cur%%=*}" && COMPREPLY=($(compgen -P "$prefix" -W "$REPLY" -- "${cur#*=}"))
                  return 0
                fi
                if [[ $cur == -* ]]; then
                  __#{@id}_complete_options "$node" && COMPREPLY=($(compgen -W "$REPLY" -- "$cur"))
                  return 0
                fi
                [[ -z $positional ]] && __#{@id}_complete_words "$node" && COMPREPLY=($(compgen -W "$REPLY" -- "$cur"))
                return 0
              }

              complete -o default -F _#{@id} #{sq(@name)}
            BASH
          end

          def zsh
            <<~ZSH
              #compdef #{@name}
              # zsh completion for #{@name}
              # Generated by `#{@name} completion zsh`; regenerate it when the tool changes.
              # Load it in this shell (after compinit):  eval "$(#{@name} completion zsh)"
              # Or save it on your $fpath:  #{@name} completion zsh > "${fpath[1]}/_#{@id}"

              #{next_function}

              #{takes_value_function}

              # Status 0 with the choices in $candidates, 2 for a path, 1 for any other value.
              __#{@id}_complete_choices() {
                case "$1 $2" in
              #{indent(choice_cases { |words| "candidates=(#{words.map { |w| sq(w) }.join(" ")})" }, 4)}
              #{indent(path_cases, 4)}
                  *) return 1 ;;
                esac
              }

              __#{@id}_complete_options() {
                case "$1" in
              #{indent(@tree.nodes.map { |n| "#{n.id}) candidates=(#{described_options(n)}) ;;  # #{n.command.full_name}" }, 4)}
                  *) return 1 ;;
                esac
              }

              __#{@id}_complete_words() {
                case "$1" in
              #{indent(word_nodes.map { |n| "#{n.id}) REPLY=#{word_kind(n)} candidates=(#{n.words.map { |w, d| described(w, d) }.join(" ")}) ;;  # #{n.command.full_name}" }, 4)}
                  *) return 1 ;;
                esac
              }

              _#{@id}() {
                local node=0 word cur=${words[CURRENT]} skip= positional= REPLY i rc
                local -a candidates
                for (( i = 2; i < CURRENT; i++ )); do
                  word=${words[i]}
                  if [[ -n $skip ]]; then skip=; continue; fi
                  case $word in
                    --) _files; return ;;
                    --*=*) ;;
                    --*) __#{@id}_complete_takes_value $node "$word" && skip=$word ;;
                    -?*) __#{@id}_complete_takes_value $node "-${word[-1]}" && skip="-${word[-1]}" ;;
                    *)
                      if [[ -z $positional ]] && __#{@id}_complete_next "$node $word"; then node=$REPLY; else positional=1; fi ;;
                  esac
                done
                if [[ -z $skip && $cur == --*=* ]]; then
                  skip=${cur%%=*}
                  compset -P '*='
                fi
                if [[ -n $skip ]]; then
                  __#{@id}_complete_choices $node "$skip"
                  rc=$?
                  if (( rc == 0 )); then compadd -a candidates; elif (( rc == 2 )); then _files; fi
                  return
                fi
                if [[ $cur == -* ]]; then
                  __#{@id}_complete_options $node && _describe -t options option candidates
                  return
                fi
                if [[ -z $positional ]] && __#{@id}_complete_words $node; then
                  _describe -t ${REPLY}s $REPLY candidates
                else
                  _files
                fi
              }

              if [ "$funcstack[1]" = "_#{@id}" ]; then
                _#{@id} "$@"
              else
                compdef _#{@id} #{sq(@name)}
              fi
            ZSH
          end

          def fish
            cmd = fq(@name)
            <<~FISH
              # fish completion for #{@name}
              # Generated by `#{@name} completion fish`; regenerate it when the tool changes.
              # Load it in this shell:  #{@name} completion fish | source
              # Or save it:  #{@name} completion fish > ~/.config/fish/completions/#{@name}.fish

              function __#{@id}_complete_next
                  switch $argv[1]
              #{indent(fish_next_cases, 8)}
                  end
                  return 1
              end

              function __#{@id}_complete_takes_value
                  switch "$argv[1] $argv[2]"
              #{indent(fish_value_cases, 8)}
                  end
                  return 1
              end

              # The node the command line is at; "N+" once a positional argument was typed.
              function __#{@id}_complete_node
                  set -l node 0
                  set -l skip 0
                  set -l positional 0
                  set -l tokens (commandline -opc)
                  set -e tokens[1]
                  for word in $tokens
                      if test $skip = 1
                          set skip 0
                          continue
                      end
                      if test "$word" = --
                          echo $node+
                          return
                      else if string match -q -- '--*=*' $word
                          continue
                      else if string match -q -- '-?*' $word
                          set -l opt $word
                          string match -q -- '--*' $word; or set opt -(string sub -s -1 -- $word)
                          __#{@id}_complete_takes_value $node $opt; and set skip 1
                      else if test $positional = 0; and __#{@id}_complete_next "$node $word" >/dev/null
                          set node (__#{@id}_complete_next "$node $word")
                      else
                          set positional 1
                      end
                  end
                  if test $positional = 1
                      echo $node+
                  else
                      echo $node
                  end
              end

              # Before any positional argument: where command names complete.
              function __#{@id}_complete_at
                  test (__#{@id}_complete_node) = $argv[1]
              end

              # Anywhere in the command: where its options complete.
              function __#{@id}_complete_in
                  set -l node (__#{@id}_complete_node)
                  test "$node" = $argv[1]; or test "$node" = "$argv[1]+"
              end

              #{fish_entries(cmd).join("\n")}
            FISH
          end

          private

          def word_nodes = @tree.nodes.select { |n| n.words.any? }

          def word_kind(node) = node.command.declared(:completion_command).any? ? "shell" : "command"

          def option_words(node)
            node.options.flat_map { |o| [o[:long], o[:short], o[:negation]] }.compact
          end

          def value_options(node) = node.options.select { |o| o[:value] }

          def next_function
            cases = @tree.links.group_by(&:last).map do |to, links|
              "#{links.map { |from, word, _| sq("#{from} #{word}") }.join("|")}) REPLY=#{to} ;;"
            end
            <<~SH.chomp
              __#{@id}_complete_next() {
                case "$1" in
              #{indent(cases, 4)}
                  *) return 1 ;;
                esac
              }
            SH
          end

          def takes_value_function
            cases = @tree.nodes.filter_map do |n|
              names = value_options(n).flat_map { |o| [o[:long], o[:short]] }.compact
              "#{names.map { |name| sq("#{n.id} #{name}") }.join("|")}) return 0 ;;" if names.any?
            end
            <<~SH.chomp
              __#{@id}_complete_takes_value() {
                case "$1 $2" in
              #{indent(cases, 4)}
                esac
                return 1
              }
            SH
          end

          def choice_cases
            @tree.nodes.flat_map do |n|
              value_options(n).select { |o| o[:choices] }.map do |o|
                "#{option_keys(n, o)}) #{yield o[:choices]} ;;"
              end
            end
          end

          def path_cases
            @tree.nodes.flat_map do |n|
              value_options(n).select { |o| o[:path] && !o[:choices] }.map { |o| "#{option_keys(n, o)}) return 2 ;;" }
            end
          end

          def option_keys(node, option)
            [option[:long], option[:short]].compact.map { |name| sq("#{node.id} #{name}") }.join("|")
          end

          def described_options(node)
            node.options.flat_map do |o|
              [o[:long], o[:short], o[:negation]].compact.map { |name| described(name, o[:desc]) }
            end.join(" ")
          end

          def described(word, desc)
            word = word.gsub(":", "\\:")
            sq(desc.to_s.empty? ? word : "#{word}:#{desc.to_s.lines.first.chomp}")
          end

          def fish_next_cases
            @tree.links.group_by(&:last).map do |to, links|
              "case #{links.map { |from, word, _| fq("#{from} #{word}") }.join(" ")}\n    echo #{to}\n    return 0"
            end
          end

          def fish_value_cases
            @tree.nodes.filter_map do |n|
              names = value_options(n).flat_map { |o| [o[:long], o[:short]] }.compact
              "case #{names.map { |name| fq("#{n.id} #{name}") }.join(" ")}\n    return 0" if names.any?
            end
          end

          def fish_entries(cmd)
            lines = []
            word_nodes.each do |n|
              lines << "# #{n.command.full_name}"
              n.words.each do |word, desc|
                lines << "complete -c #{cmd} -f -n '__#{@id}_complete_at #{n.id}' -a #{fq(escape(word))}#{fish_desc(desc)}"
              end
            end
            @tree.nodes.each do |n|
              lines << "# #{n.command.full_name} options"
              n.options.each do |o|
                next if o.equal?(HELP)

                lines << "complete -c #{cmd} -n '__#{@id}_complete_in #{n.id}'#{fish_option(o)}#{fish_desc(o[:desc])}"
                if o[:negation]
                  lines << "complete -c #{cmd} -n '__#{@id}_complete_in #{n.id}' -l #{fq(o[:negation].delete_prefix("--"))}#{fish_desc(o[:desc])}"
                end
              end
            end
            lines << "complete -c #{cmd} -s h -l help -d 'Show help'"
          end

          def fish_option(option)
            parts = []
            parts << "-s #{fq(option[:short].delete_prefix("-"))}" if option[:short]
            parts << "-l #{fq(option[:long].delete_prefix("--"))}"
            if option[:choices]
              parts << "-x -a #{fq(option[:choices].map { |c| escape(c) }.join(" "))}"
            elsif option[:path]
              parts << "-r -F"
            elsif option[:value]
              parts << "-x"
            end
            " #{parts.join(" ")}"
          end

          def fish_desc(desc) = desc.to_s.empty? ? "" : " -d #{fq(desc.to_s.lines.first.chomp)}"

          def indent(lines, spaces) = lines.flat_map { |l| l.split("\n") }.map { |l| (" " * spaces) + l }.join("\n")

          SAFE = %r{\A[\w.,:@%+=/-]+\z}

          # A word for bash and zsh: bare when safe, else single-quoted.
          def sq(text)
            text = text.to_s
            text.match?(SAFE) ? text : "'#{text.gsub("'") { "'\\''" }}'"
          end

          # A word for fish: bare when safe, else single-quoted (where \\ and \' are the only escapes).
          def fq(text)
            text = text.to_s
            text.match?(SAFE) ? text : "'#{text.gsub(/[\\']/) { "\\#{::Regexp.last_match(0)}" }}'"
          end

          # A word as it must appear in a list the shell expands again (compgen -W, complete -a).
          def escape(word) = word.to_s.gsub(%r{[^\w.,:@%+=/-]}) { "\\#{::Regexp.last_match(0)}" }
        end
      end
    end

    extension :completion do
      dsl(:command) do
        # On the root: adds `completion <bash|zsh|fish>`.
        def completion
          raise ArgumentError, "completion goes on the root command, not #{definition.full_name}" unless definition.root?

          declare(:completion, true)
        end
      end

      setup do
        if declared(:completion).any?
          tool = definition.name
          command :completion, "Print a shell completion script" do
            description "Print a shell completion script for #{tool}: it completes commands, aliases, options and their choices."
            declare(:completion_command, true)
            argument :shell, desc: "bash, zsh or fish"
            run do
              kind = args[:shell]
              usage_error!(Ext::Completion.unknown(kind)) unless Ext::Completion::SHELLS.key?(kind)

              shell.print(Ext::Completion.script(program, kind))
              if shell.live?
                line = format(Ext::Completion::SETUP.fetch(kind).first, program.name)
                shell.err_puts("#{shell.symbol(:info)} Load it with #{shell.paint(line, :accent)} #{shell.paint("(#{program.name} completion --help)", :muted)}")
              end
            end
          end
        end
      end

      help_section do |command, shell|
        ["Setup", Ext::Completion.setup_lines(shell, command.root.name)] if command.declared(:completion_command).any?
      end
    end
  end
end
