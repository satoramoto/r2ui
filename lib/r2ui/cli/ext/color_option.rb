# frozen_string_literal: true

# c31-color-option: let the person running a tool turn colour on or off.
#
#   R2UI.cli "deployer" do
#     color_option                      # on the root: every command takes --color / --no-color
#     command(:deploy) { run { say "Deployed", :success } }
#   end
#
#   deployer deploy --no-color          # on a terminal: no colour codes, live redraw still happens
#   deployer deploy --color | less -R   # in a pipe: styled as on a terminal, one line per event
#
# Without either flag the shell decides as usual (NO_COLOR, FORCE_COLOR, a terminal or not). Given,
# the flag wins over those variables, and the last one given wins (`--color --no-color` is off).
# It only changes colour: a pipe still gets plain stable lines (no spinners or cursor movement),
# and a terminal still redraws live output in place.
#
# The flag is applied right after argv is parsed, so usage errors about arguments, the command's
# output and its error report all follow it. `tool --no-color --help` is the exception: the core
# prints help before any extension hook runs.
#
# Lipgloss picks its colour profile once from the process's stdout, which is "no colour" when stdout
# is piped; `--color` raises that to the 16-colour ANSI profile (the theme uses palette numbers), so
# the styles really come out in a pipe.
module R2UI
  module CLI
    module Ext
      module ColorOption
        module_function

        def apply(shell, on)
          shell.color = on
          force_lipgloss_colour if on
        end

        def force_lipgloss_colour
          renderer = R2UI::Compat::Gloss::Renderer
          renderer.color_profile = :ansi if renderer.color_profile.to_sym == :ascii
        end
      end
    end

    extension :color_option do
      dsl(:command) do
        # Adds --color / --no-color to every command (on the root only).
        def color_option
          raise ArgumentError, "color_option belongs on the root command" unless definition.root?

          declare(:color_option, true)
        end
      end

      setup do
        if declared(:color_option).any?
          flag :color, default: nil, desc: "Colour the output (--no-color turns it off; default: on a terminal)"
        end
      end

      after_parse do
        Ext::ColorOption.apply(shell, options[:color]) if program.declared(:color_option).any? && given?(:color)
      end
    end
  end
end
