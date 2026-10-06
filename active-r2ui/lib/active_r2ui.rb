# frozen_string_literal: true

require "r2ui"
require "active_record"

require_relative "active_r2ui/version"
require_relative "active_r2ui/timestamp"
require_relative "active_r2ui/decimal"
require_relative "active_r2ui/columns"
require_relative "active_r2ui/resource_builder"
require_relative "active_r2ui/model_list"
require_relative "active_r2ui/extension"
require_relative "active_r2ui/browser"
require_relative "active_r2ui/command"

# ActiveR2UI: r2ui dashboards for a Rails app's ActiveRecord models.
#
#   # app/tui/orders.rb
#   ActiveR2UI.register Order do
#     limit 1000
#     scope :pending              # Order.pending, over the fetched window (see README)
#     action :ship, key: "S"      # calls order.ship on each selected record
#   end
#
# `bin/rails tui` registers every other concrete model with the defaults and opens the model list.
module ActiveR2UI
  class Error < StandardError; end
  class ReadOnlyError < Error; end

  # Rows fetched per model (newest first by primary key); `limit` in a register block changes it.
  DEFAULT_LIMIT = 500
  # Seconds between fetches of a model's table.
  DEFAULT_REFRESH = 5.0

  class << self
    # Model resources by r2ui resource name.
    def models = @models ||= {}

    # Customises a model with r2ui's resource DSL plus Rails defaults (see ResourceBuilder).
    # `as:` names the screen (default: the model's plural, e.g. :orders, :admin_users).
    def register(model, as: nil, &block)
      raise Error, "ActiveR2UI.register needs an ActiveRecord model, got #{model.inspect}" unless model.is_a?(Class) && model < ActiveRecord::Base

      name = (as || resource_name(model)).to_sym
      resource = with_connection(model) { ResourceBuilder.build(name, model, &block) }
      models[name] = model
      R2UI.registry.add_resource(resource)
    end

    def resource_name(model) = model.model_name.plural.to_sym

    def registered?(model) = models.value?(model)

    # Concrete models with a table, sorted by name: no abstract classes, no STI subclasses (they
    # share their base class's table), no Rails internals or anonymous HABTM join classes.
    def discover(base = ActiveRecord::Base)
      base.descendants.select { |model| concrete?(model) }.sort_by(&:name)
    end

    def concrete?(model)
      name = model.name
      return false if name.nil? || model.abstract_class? || name.start_with?("ActiveRecord::") || name.include?("HABTM_")
      return false unless model.base_class == model

      with_connection(model) { model.table_exists? }
    rescue StandardError
      false
    end

    # Registers the defaults for every discovered model not registered yet, then the model list
    # (resource and dashboard ModelList::NAME).
    def install!(models = discover)
      models.each { |model| register(model) unless registered?(model) }
      ModelList.install
    end

    # Eager-loads the app, loads app/tui/**/*.rb (the user's registrations) and installs the rest.
    def boot!(app = Rails.application)
      begin
        app.eager_load!
      rescue StandardError, LoadError => e
        warn "active-r2ui: eager loading stopped (#{e.class}: #{e.message}); showing the models loaded so far"
      end
      Dir[File.join(app.root.to_s, "app", "tui", "**", "*.rb")].sort.each { |file| load file }
      install!
    end

    # Runs the block with a database connection that is returned afterwards, inside the Rails
    # executor when there is a Rails app (feed threads, actions).
    def with_connection(model = ActiveRecord::Base, &block)
      run = -> { model.connection_pool.with_connection { block.call } }
      executor = rails_executor
      executor ? executor.wrap(&run) : run.call
    end

    # Actions refuse to run when true. The `tui` command sets it: true in production unless
    # --allow-writes is passed.
    def read_only? = @read_only || false

    attr_writer :read_only

    # Wraps an action handler: refused when read-only, else run with a connection.
    def guard(model, handler)
      lambda do |record|
        raise ReadOnlyError, "read-only in production (restart with --allow-writes)" if read_only?

        with_connection(model) { handler.call(record) }
      end
    end

    # Forgets every registration (for tests): r2ui's registry too.
    def reset!
      @models = {}
      @read_only = false
      R2UI.reset!
    end

    private

    def rails_executor
      return nil unless defined?(::Rails) && ::Rails.respond_to?(:application)

      ::Rails.application&.executor
    end
  end
end

require "rails/railtie"
require_relative "active_r2ui/railtie"
