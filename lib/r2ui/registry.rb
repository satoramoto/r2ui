# frozen_string_literal: true

module R2UI
  # Every resource, dashboard and shared source an app defines.
  #
  # Definitions compose across files: a resource or dashboard has one definition plus any number
  # of extensions (`extend: true`, R2UI.panel), applied in load order on top of it whichever loads
  # first. Defining a name twice from two places is an error (pass `replace: true` to mean it);
  # defining it again from the same place (a file loaded twice) replaces the earlier definition.
  class Registry
    attr_reader :resources, :dashboards, :sources

    # A definition: a block (or an already built object) and where it came from.
    Definition = Data.define(:body, :location)

    def initialize
      @resources = {}
      @dashboards = {}
      @sources = {}
      @definitions = { resource: {}, dashboard: {}, source: {} }
      @extensions = { resource: Hash.new { |h, k| h[k] = {} }, dashboard: Hash.new { |h, k| h[k] = {} } }
    end

    # --- the DSL entry points (R2UI.resource, R2UI.dashboard, R2UI.panel, R2UI.source) ---

    # Defines (or with `extend: true`, adds to) a resource. Returns the resource (nil when only
    # extensions exist so far).
    def define_resource(name, extend: false, replace: false, location: nil, &block)
      define(:resource, name.to_sym, Definition.new(body: block, location: location || block&.source_location),
             extend:, replace:)
      @resources[name.to_sym]
    end

    # Defines (or with `extend: true`, adds to) a dashboard. Returns the dashboard.
    def define_dashboard(name, extend: false, replace: false, location: nil, &block)
      define(:dashboard, name.to_sym, Definition.new(body: block, location: location || block&.source_location),
             extend:, replace:)
      @dashboards[name.to_sym]
    end

    # A shared source: fetched once per `every` seconds per app, read by `source from: name`.
    def define_source(name, every: DSL::Resource::DEFAULT_INTERVAL, replace: false, location: nil, &block)
      raise ArgumentError, "source #{name} needs a block" unless block
      raise ArgumentError, "source #{name}: every: must be positive" unless every.to_f.positive?

      name = name.to_sym
      check_redefinition(:source, name, location || block.source_location, replace)
      @definitions[:source][name] = Definition.new(body: block, location: location || block.source_location)
      @sources[name] = DSL::Source.new(name:, interval: every.to_f, block:)
    end

    # --- built objects (back compatible: these replace silently, like before) ---

    def add_resource(resource)
      @definitions[:resource][resource.name] = Definition.new(body: resource, location: nil)
      rebuild(:resource, resource.name)
      @resources[resource.name]
    end

    def add_dashboard(dashboard)
      @definitions[:dashboard][dashboard.name] = Definition.new(body: dashboard, location: nil)
      rebuild(:dashboard, dashboard.name)
      @dashboards[dashboard.name]
    end

    def resource(name) = @resources.fetch(name.to_sym) { raise Error, "no resource named #{name}" }

    def source(name) = @sources.fetch(name.to_sym) { raise Error, "no source named #{name}" }

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

    private

    # Records the definition or extension and rebuilds; if building raises, the registry is left
    # as it was.
    def define(kind, name, definition, extend:, replace:)
      unless extend
        trial(kind, name, definition) # a mistake inside the block is reported before a redefinition
        check_redefinition(kind, name, definition.location, replace)
      end
      saved_definition = @definitions[kind][name]
      saved_extensions = @extensions[kind][name].dup
      if extend
        # Keyed by location, so a file loaded twice replaces its own extension instead of adding it twice.
        key = definition.location || definition.body.object_id
        @extensions[kind][name].delete(key)
        @extensions[kind][name][key] = definition
      else
        @definitions[kind][name] = definition
      end
      begin
        rebuild(kind, name)
      rescue StandardError
        saved_definition ? @definitions[kind][name] = saved_definition : @definitions[kind].delete(name)
        @extensions[kind][name] = saved_extensions
        @extensions[kind].delete(name) if saved_extensions.empty?
        raise
      end
    end

    def trial(kind, name, definition)
      return unless definition.body.is_a?(Proc)

      kind == :resource ? DSL::Resource.new(name).apply(&definition.body) : DSL::Dashboard.build(name, &definition.body)
    end

    def check_redefinition(kind, name, location, replace)
      old = @definitions[kind][name]
      return if replace || old.nil? || old.location.nil? || location.nil? || old.location == location

      raise Error, "#{kind} #{name} is already defined at #{old.location.join(":")}; " \
                   "pass extend: true to add to it, or replace: true to replace it"
    end

    # Builds the definition, then applies every extension in load order. Nothing changes if any
    # block raises.
    def rebuild(kind, name)
      definition = @definitions[kind][name]
      extensions = @extensions[kind].fetch(name, {}).values
      case kind
      when :resource
        return unless definition

        resource = base(definition) { |b| DSL::Resource.new(name).apply(&b) }
        extensions.each { |e| resource.apply(&e.body) }
        @resources[name] = resource.validate!
      when :dashboard
        dashboard = definition ? base(definition) { |b| DSL::Dashboard.build(name, &b) } : DSL::Dashboard.new(name)
        extensions.each { |e| dashboard.apply(&e.body) }
        @dashboards[name] = dashboard
      end
    end

    # A fresh object from a definition: a block is run again, a built object is copied (so
    # extensions never change the caller's object).
    def base(definition)
      body = definition.body
      body.is_a?(Proc) || body.nil? ? yield(body) : body.dup
    end
  end
end
