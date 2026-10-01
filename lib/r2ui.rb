# frozen_string_literal: true

# r2ui runs on its own pure-Ruby Bubbletea, so `require "bubbletea"` / `require "lipgloss"` /
# `require "bubbles"` after this resolve to r2ui's versions (see r2ui/drop_in).
require_relative "r2ui/drop_in"
require "bubbletea"

require_relative "r2ui/version"
require_relative "r2ui/value"
require_relative "r2ui/format"
require_relative "r2ui/history"
require_relative "r2ui/dsl/column"
require_relative "r2ui/dsl/resource"
require_relative "r2ui/dsl/dashboard"
require_relative "r2ui/registry"
require_relative "r2ui/search"
require_relative "r2ui/query"
require_relative "r2ui/canvas"
require_relative "r2ui/widgets/box"
require_relative "r2ui/widgets/table"
require_relative "r2ui/widgets/gauge"
require_relative "r2ui/widgets/stat"
require_relative "r2ui/widgets/sparkline"
require_relative "r2ui/panel_state"
require_relative "r2ui/feed"
require_relative "r2ui/renderer"
require_relative "r2ui/keys"
require_relative "r2ui/context"
require_relative "r2ui/extension"
require_relative "r2ui/component"
require_relative "r2ui/app"

# R2UI: declare terminal dashboards the way ActiveAdmin declares admin pages.
#
#   R2UI.resource :process do
#     source { MyProbe.processes }
#     scope :all, default: true
#     group_by :name
#     index { column :pid, format: :id; column :cpu, format: :percent }
#   end
#
#   R2UI.run
module R2UI
  class Error < StandardError; end

  class << self
    def registry = @registry ||= Registry.new

    def resource(name, &) = registry.add_resource(DSL::Resource.build(name, &))

    def dashboard(name = :main, &) = registry.add_dashboard(DSL::Dashboard.build(name, &))

    def run(name = nil) = App.new(registry, name).run

    # One frame as plain text, without a terminal. Used by `r2ui --snapshot` and tests.
    def snapshot(name = nil, width: 120, height: 40, ticks: 1) = App.new(registry, name).snapshot(width:, height:, ticks:)

    def reset! = @registry = Registry.new
  end
end

# Capabilities: one self-registering file each (docs/dsl.md).
R2UI::Extensions.load_all
