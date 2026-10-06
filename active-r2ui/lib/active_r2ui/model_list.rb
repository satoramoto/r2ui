# frozen_string_literal: true

module ActiveR2UI
  # The default screen: one line per registered model (name, screen name, table, row count).
  # In the browser, enter opens the selected model's table.
  module ModelList
    NAME = :active_r2ui_models
    REFRESH = 30.0

    Entry = Data.define(:model, :screen, :table, :rows, :note)

    module_function

    def install(registry = R2UI.registry)
      registry.add_resource(R2UI::DSL::Resource.build(NAME) do
        title "Models"
        source { ModelList.entries }
        refresh every: REFRESH
        key :screen
        index do
          column :model, sort: :asc
          column :screen
          column :table
          column :rows, format: :integer
          column :note, priority: -1
        end
        filter :model, :screen, :table
      end)
      registry.add_dashboard(R2UI::DSL::Dashboard.build(NAME) do
        title "Models"
        row { panel NAME, title: "Models" }
      end)
    end

    # Counts each table (respecting default scopes) with its own connection; a failing count shows
    # its error in the note column instead of hiding the model.
    def entries
      ActiveR2UI.models.map do |screen, model|
        rows, note = count(model)
        Entry.new(model: model.name, screen: screen.to_s, table: model.table_name, rows:, note:)
      end
    end

    def count(model)
      [ActiveR2UI.with_connection(model) { model.count }, nil]
    rescue StandardError => e
      [nil, "#{e.class}: #{e.message}"]
    end
  end
end
