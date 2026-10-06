# frozen_string_literal: true

module ActiveR2UI
  # What `bin/rails tui [SCREEN]` does once the app is booted:
  #
  #   bin/rails tui                     the model list; enter opens a model, esc goes back
  #   bin/rails tui orders              one model (or an R2UI.dashboard from app/tui) full screen
  #   bin/rails tui --snapshot [SCREEN] print one frame as plain text and exit (--width, --height)
  #
  # In production, actions are refused unless --allow-writes is given.
  class Command
    def initialize(screen: nil, snapshot: false, width: 120, height: 40, allow_writes: false,
                   production: false, out: $stdout)
      @screen = screen
      @snapshot = snapshot
      @width = width
      @height = height
      @allow_writes = allow_writes
      @production = production
      @out = out
    end

    # Runs after ActiveR2UI.boot! (or install!) has registered the models.
    def run
      ActiveR2UI.read_only = @production && !@allow_writes
      name = @screen && ActiveR2UI::Command.resolve(@screen)
      if @snapshot
        app = R2UI::App.new(R2UI.registry, name || ModelList::NAME)
        begin
          @out.puts app.snapshot(width: @width, height: @height)
        ensure
          app.stop
        end
      elsif name
        R2UI::App.new(R2UI.registry, name).run
      else
        Browser.new.run
      end
    end

    # The screen for what the user typed: a dashboard or resource name ("orders"), or a model
    # name in any common spelling ("Order", "order", "admin/user", the table name).
    def self.resolve(text, registry = R2UI.registry)
      name = text.to_s.to_sym
      return name if registry.dashboards.key?(name) || registry.resources.key?(name)

      wanted = text.to_s.downcase.tr("/", ":").delete("_")
      found = ActiveR2UI.models.find do |_screen, model|
        [model.name, model.name.underscore, model.model_name.singular, model.table_name]
          .any? { |n| n.to_s.downcase.tr("/", ":").delete("_") == wanted }
      end
      return found.first if found

      known = ActiveR2UI.models.keys.map(&:to_s).sort.join(", ")
      raise Error, "no model or screen named #{text.inspect} (models: #{known})"
    end
  end
end
