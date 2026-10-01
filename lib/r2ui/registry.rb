# frozen_string_literal: true

module R2UI
  class Registry
    attr_reader :resources, :dashboards

    def initialize
      @resources = {}
      @dashboards = {}
    end

    def add_resource(resource) = @resources[resource.name] = resource

    def add_dashboard(dashboard) = @dashboards[dashboard.name] = dashboard

    def resource(name) = @resources.fetch(name.to_sym) { raise Error, "no resource named #{name}" }

    # A dashboard by name, or a resource shown full screen. With no name: :main, else the first defined.
    def screen(name = nil)
      name = name&.to_sym
      return dashboards[name] if name && dashboards.key?(name)
      return DSL::Dashboard.for_resource(resource(name)) if name
      return dashboards[:main] if dashboards.key?(:main)
      return dashboards.values.first if dashboards.any?
      raise Error, "nothing to show: define a resource or dashboard" if resources.empty?

      DSL::Dashboard.for_resource(resources.values.first)
    end
  end
end
