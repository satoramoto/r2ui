# frozen_string_literal: true

# r2ui runs on its own pure-Ruby Bubbletea, loaded by path. This doesn't touch $LOAD_PATH:
# `require "bubbletea"` still means whatever it meant; `require "r2ui/drop_in"` opts into r2ui's.
require_relative "r2ui/compat/bubbletea"

require_relative "r2ui/version"
require_relative "r2ui/value"
require_relative "r2ui/format"
require_relative "r2ui/history"
require_relative "r2ui/dsl/column"
require_relative "r2ui/dsl/resource"
require_relative "r2ui/dsl/dashboard"
require_relative "r2ui/registry"
require_relative "r2ui/source"
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

    # Defines a resource. `extend: true` adds to one defined elsewhere (columns, scopes, actions),
    # in either load order; defining the same name from two places raises unless `replace: true`.
    def resource(name, extend: false, replace: false, &block)
      registry.define_resource(name, extend:, replace:, location: location(block), &block)
    end

    # Defines a dashboard; `extend: true` / `replace: true` as for `resource`. Extending runs the
    # block on the same builder: `row :top do panel ... end` adds to the named row.
    def dashboard(name = :main, extend: false, replace: false, &block)
      registry.define_dashboard(name, extend:, replace:, location: location(block), &block)
    end

    # Adds one panel to a dashboard from any file:
    #
    #   R2UI.panel :memory, row: :top, order: 10, resource: nil do view { "..." } end
    #
    # `row:` names the row (created at the end, flexible, if no file declared it; omitted: a row
    # of its own); `order:` places the panel in its row. Other options are `panel`'s.
    def panel(name, dashboard: :main, row: nil, order: 0, **options, &block)
      at = caller_locations(1, 1).first
      registry.define_dashboard(dashboard, extend: true, location: [at.path, at.lineno]) do
        row(row) { panel(name, order:, **options, &block) }
      end
    end

    # A data source several resources share: fetched at most once per `every` seconds per app.
    # The block gets the previous value. Resources read it with `source from: name`.
    def source(name, every: DSL::Resource::DEFAULT_INTERVAL, replace: false, &block)
      registry.define_source(name, every:, replace:, location: location(block), &block)
    end

    def run(name = nil) = App.new(registry, name).run

    # One frame as plain text, without a terminal. Used by `r2ui --snapshot` and tests.
    def snapshot(name = nil, width: 120, height: 40, ticks: 1)
      App.new(registry, name).snapshot(width:, height:, ticks:)
    end

    def reset! = @registry = Registry.new

    # Runs the block with `registry` as R2UI.registry (a new one by default), so definitions
    # loaded inside go there; returns it. For tests and apps that build a registry per run:
    #
    #   registry = R2UI.with_registry { load "app/ui.rb" }
    #   R2UI::App.new(registry).frame(120, 40)
    #
    # Not thread-safe: use it while loading, not while another thread defines things.
    def with_registry(registry = Registry.new)
      previous = @registry
      @registry = registry
      yield registry
      registry
    ensure
      @registry = previous
    end

    private

    def location(block) = block&.source_location
  end
end

# Capabilities: one self-registering file each (docs/dsl.md).
R2UI::Extensions.load_all
