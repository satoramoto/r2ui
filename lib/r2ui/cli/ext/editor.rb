# frozen_string_literal: true

require "shellwords"
require "tempfile"

# c22-editor: let the user write something in their own editor, like `git commit`.
#
#   notes = edit("# Release notes\n\n")                  # => what they saved
#   config = edit(File.read("app.yml"), ext: ".yml")     # the extension picks the syntax highlighting
#
# On a terminal (Shell#interactive?) it writes `text` to a temp file, runs `$VISUAL`, else
# `$EDITOR`, else `vi` on it in the foreground (on the tool's own terminal) and returns the saved
# contents. While the editor is open the tool shows
#
#   ℹ Waiting for your editor to close the file…
#
# (seen behind GUI editors such as `code --wait`), and erases it when the editor exits. The editor
# command may carry arguments (`EDITOR="code --wait"`). The temp file is removed on every path:
# return, an editor that fails ("editor vi exited with status 1", a CLI::Error), one that can't be
# started, or ctrl+c.
#
# Off an interactive shell (a pipe, CI, TERM=dumb) there is nobody to edit, so it raises a
# CLI::Error ("edit needs a terminal ...") without starting the editor; a command exits 1 with
# that message on stderr. Read the text from a file or stdin instead in that case.
module R2UI
  module CLI
    module Ext
      module Editor
        DEFAULT = "vi"

        module_function

        # The editor command as argv words: $VISUAL, $EDITOR, then vi.
        def command(shell)
          [shell.env["VISUAL"], shell.env["EDITOR"]].each do |value|
            words = value.to_s.strip.empty? ? [] : Shellwords.split(value)
            return words unless words.empty?
          end
          [DEFAULT]
        end

        def edit(shell, text, ext)
          unless shell.interactive?
            raise Error, "edit needs a terminal: run this from an interactive shell (it opens $VISUAL or $EDITOR)"
          end

          words = command(shell)
          Tempfile.create(["r2ui-edit-", ext.to_s]) do |file|
            file.write(text.to_s)
            file.close
            run(shell, words, file.path)
            File.read(file.path, mode: "r:UTF-8")
          end
        end

        def run(shell, words, path)
          hint(shell)
          ok = begin
            system(*words, path, **redirects(shell))
          ensure
            shell.print("\r\e[2K") if shell.live?
          end
          name = File.basename(words.first)
          raise Error, "could not start editor #{name.inspect}: set $VISUAL or $EDITOR" if ok.nil?
          return if ok

          status = $?
          raise Error, "editor #{name} exited with status #{status.exitstatus}" if status.exitstatus

          raise Error, "editor #{name} was stopped (signal #{status.termsig})"
        end

        def hint(shell)
          return unless shell.live?

          shell.print("#{shell.symbol(:info)} #{shell.paint("Waiting for your editor to close the file…", :muted)}")
        end

        # The editor gets the tool's own terminal (only real IOs can be handed to a child).
        def redirects(shell)
          { in: shell.input, out: shell.output, err: shell.error }.select { |_, io| io.is_a?(IO) }
        end
      end
    end

    extension :editor do
      helpers do
        def edit(text = "", ext: ".md")
          Ext::Editor.edit(shell, text, ext)
        end
      end
    end
  end
end
