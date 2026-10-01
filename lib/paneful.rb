# frozen_string_literal: true

require_relative "paneful/version"
require_relative "paneful/value"
require_relative "paneful/format"
require_relative "paneful/history"
require_relative "paneful/dsl/column"
require_relative "paneful/dsl/resource"
require_relative "paneful/dsl/dashboard"
require_relative "paneful/registry"
require_relative "paneful/search"
require_relative "paneful/query"
require_relative "paneful/canvas"
require_relative "paneful/widgets/box"
require_relative "paneful/widgets/table"
require_relative "paneful/widgets/gauge"
require_relative "paneful/widgets/stat"
require_relative "paneful/widgets/sparkline"
require_relative "paneful/panel_state"
require_relative "paneful/feed"
require_relative "paneful/renderer"
require_relative "paneful/keys"
require_relative "paneful/terminal"
require_relative "paneful/app"

# Paneful: declare terminal dashboards the way ActiveAdmin declares admin pages.
#
#   Paneful.resource :process do
#     source { MyProbe.processes }
#     scope :all, default: true
#     group_by :name
#     index { column :pid, format: :id; column :cpu, format: :percent }
#   end
#
#   Paneful.run
module Paneful
  class Error < StandardError; end

  class << self
    def registry = @registry ||= Registry.new

    def resource(name, &) = registry.add_resource(DSL::Resource.build(name, &))

    def dashboard(name = :main, &) = registry.add_dashboard(DSL::Dashboard.build(name, &))

    def run(name = nil) = App.new(registry, name).run

    # One frame as plain text, without a terminal. Used by `paneful --snapshot` and tests.
    def snapshot(name = nil, width: 120, height: 40, ticks: 1) = App.new(registry, name).snapshot(width:, height:, ticks:)

    def reset! = @registry = Registry.new
  end
end
