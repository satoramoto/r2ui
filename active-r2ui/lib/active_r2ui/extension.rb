# frozen_string_literal: true

# Keys for ActiveR2UI::Browser, through r2ui's extension point. They act only in apps a Browser
# hosts (it marks them in their `store(:active_r2ui)`): enter on the model list asks to open the
# selected model, esc on a model's screen asks to go back. The Browser reads the request after the
# update and switches screens.
R2UI.extension :active_r2ui do
  on(Bubbletea::KeyMessage) do |message|
    hosted = store(:active_r2ui)
    pass unless hosted[:browser]

    key = R2UI::Keys.name(message)
    if dashboard.name == ActiveR2UI::ModelList::NAME && key == :enter
      entry = selected_rows.first
      pass unless entry
      hosted[:open] = entry.screen.to_sym
    elsif dashboard.name != ActiveR2UI::ModelList::NAME && key == :escape
      hosted[:back] = true
    else
      pass
    end
  end

  hints do
    next nil unless store(:active_r2ui)[:browser]

    dashboard.name == ActiveR2UI::ModelList::NAME ? [["enter", "open"]] : [["esc", "models"]]
  end
end
