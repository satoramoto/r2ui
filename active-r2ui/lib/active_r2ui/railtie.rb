# frozen_string_literal: true

module ActiveR2UI
  # app/tui/*.rb holds `ActiveR2UI.register Order do ... end` calls, not constants, so Zeitwerk must
  # not autoload or eager-load it (it would expect app/tui/order.rb to define Order). The `tui`
  # command loads those files itself (ActiveR2UI.boot!).
  class Railtie < ::Rails::Railtie
    initializer "active_r2ui.ignore_app_tui" do |app|
      ::Rails.autoloaders.main.ignore(app.root.join("app", "tui"))
    end
  end
end
