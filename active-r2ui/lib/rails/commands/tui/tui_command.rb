# frozen_string_literal: true

require "rails/command/environment_argument"
# Before the app boots, so the Railtie (app/tui ignored by Zeitwerk) is in place even when the
# gem isn't autorequired.
require "active_r2ui"

module Rails
  module Command
    # `bin/rails tui`, from the active-r2ui gem. Rails finds it on the load path by name.
    class TuiCommand < Base
      include EnvironmentArgument

      class_option :snapshot, type: :boolean, default: false, desc: "Print one frame as plain text and exit"
      class_option :width, type: :numeric, default: 120, desc: "Snapshot width"
      class_option :height, type: :numeric, default: 40, desc: "Snapshot height"
      class_option :allow_writes, type: :boolean, default: false,
                                  desc: "Allow actions in production (read-only there by default)"

      desc "tui [SCREEN]", "Browse your models in a terminal dashboard (active-r2ui)"
      def perform(screen = nil)
        respond_to?(:boot_application!, true) ? boot_application! : require_application_and_environment!
        ActiveR2UI.boot!
        ActiveR2UI::Command.new(
          screen:, snapshot: options[:snapshot], width: options[:width], height: options[:height],
          allow_writes: options[:allow_writes], production: Rails.env.production?
        ).run
      rescue ActiveR2UI::Error => e
        error e.message
        exit 1
      end
    end
  end
end
