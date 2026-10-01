# frozen_string_literal: true

module R2UI
  module DSL
    Scope = Data.define(:name, :label, :default, :filter) do
      def call(rows) = filter ? rows.select(&filter) : rows
    end

    # group_by :name (rows with the same value) or group_by :parent, tree: true (subtree totals).
    Grouping = Data.define(:name, :label, :tree, :by) do
      def tree? = tree
    end

    # `batch: true` calls the handler once with every selected row (an Array) instead of once per row.
    Action = Data.define(:name, :label, :key, :confirm, :handler, :batch) do
      def initialize(name:, label:, key:, confirm: false, handler: nil, batch: false) = super
    end

    # A named data source several resources read (R2UI.source): fetched at most once per
    # `interval` per app, however many resources and panels use it.
    Source = Data.define(:name, :interval, :block)

    # A resource definition. Built by Resource::Builder from the block given to R2UI.resource.
    class Resource
      DEFAULT_INTERVAL = 1.0
      DEFAULT_HISTORY = 120

      attr_reader :name, :title, :source, :source_from, :key, :parent_key, :scopes, :groupings, :columns,
                  :searchable, :actions

      def self.build(name, &block)
        resource = new(name)
        resource.apply(&block)
        resource.validate!
      end

      def initialize(name)
        @name = name.to_sym
        @title = name.to_s.tr("_", " ").capitalize
        @interval = nil
        @history = nil
        @scopes = []
        @groupings = []
        @columns = []
        @searchable = []
        @actions = []
        @declarations = Hash.new { |h, k| h[k] = [] }
      end

      def initialize_copy(source)
        super
        @scopes = @scopes.dup
        @groupings = @groupings.dup
        @columns = @columns.dup
        @searchable = @searchable.dup
        @actions = @actions.dup
        @declarations = Hash.new { |h, k| h[k] = [] }
        source.declarations.each { |k, v| @declarations[k] = v.dup }
      end

      # Runs a definition block on this resource's Builder (no validation). Returns self.
      def apply(&block)
        Builder.new(self).instance_eval(&block) if block
        self
      end

      # Seconds between fetches (`refresh every:`), 1.0 when not given.
      def interval = @interval || DEFAULT_INTERVAL

      # The interval given with `refresh every:`, or nil (a resource on a shared source then
      # follows the source's interval).
      def refresh_interval = @interval

      # How many points of history each sparkline keeps (`refresh history:`), 120 by default.
      def history_size = @history || DEFAULT_HISTORY

      # What extensions declared on this resource, by key.
      attr_reader :declarations

      def declared(key) = declarations.fetch(key, [])

      def column(key) = columns.find { |c| c.key == key }

      def default_scope = scopes.find(&:default) || scopes.first

      def default_sort
        col = columns.find(&:sort)
        col ? [col.key, col.sort] : nil
      end

      # The rows now. A resource reading a shared source (`source from: :name`) needs the app's
      # source cache (R2UI::Sources); Feed passes it.
      def fetch(sources = nil)
        rows = if source_from
                 raise Error, "resource #{name} reads source #{source_from}; fetch it through an app" unless sources

                 value = sources.value(source_from)
                 source ? source.call(value) : value
               else
                 source.call
               end
        rows.respond_to?(:to_ary) ? rows.to_ary : [rows]
      end

      def identify(row) = key ? Value.fetch(row, key) : row.object_id

      def validate!
        raise Error, "resource #{name} needs a `source { ... }` block" unless source || source_from
        if groupings.any?(&:tree?) && !(key && parent_key)
          raise Error, "resource #{name}: tree grouping needs `key :id_attr, parent: :parent_attr`"
        end

        self
      end

      # The DSL. Each method records a declaration on the resource.
      class Builder
        def initialize(resource) = @r = resource

        def title(text) = set(:title, text)

        # `source { rows }`, or `source from: :sample { |sample| sample[:processes] }` to read a
        # shared source (R2UI.source) and derive the rows from its value (no block: the value).
        def source(from: nil, &block)
          set(:source_from, from&.to_sym)
          set(:source, block)
        end

        # `every:` takes seconds, or anything with #to_f (an ActiveSupport::Duration).
        # `history:` is how many points each sparkline keeps (default 120).
        def refresh(every: nil, history: nil)
          set(:interval, every.to_f) if every
          return unless history
          raise ArgumentError, "history: must be a positive Integer" unless history.is_a?(Integer) && history.positive?

          set(:history, history)
        end

        # Which attribute identifies a row, and optionally which points at its parent row.
        def key(attr, parent: nil)
          set(:key, attr)
          set(:parent_key, parent)
        end

        def scope(name, label: nil, default: false, &filter)
          @r.scopes << Scope.new(name:, label: label || humanize(name), default:, filter:)
        end

        def group_by(name, label: nil, tree: false, by: name)
          @r.groupings << Grouping.new(name:, label: label || humanize(name), tree:, by:)
        end

        def index(&) = instance_eval(&)

        def column(key, **, &) = @r.columns << Column.build(key, **, &)
        alias attribute column

        # Attributes that free-text search ("/") matches against.
        def filter(*keys) = @r.searchable.concat(keys)

        # The handler runs on a Context (so it can `flash`, read `state`, ...) with each selected
        # row; `batch: true` runs it once with all of them. Its return value is ignored; raise to
        # report a failure.
        def action(name, key:, label: nil, confirm: false, batch: false, &handler)
          @r.actions << Action.new(name:, label: label || humanize(name), key:, confirm:, handler:, batch:)
        end

        private

        # For extension keywords: record `value` under `key` on the resource. Returns `value`.
        def declare(key, value)
          @r.declarations[key] << value
          value
        end

        def set(ivar, value) = @r.instance_variable_set(:"@#{ivar}", value)

        def humanize(sym) = sym.to_s.tr("_", " ").capitalize
      end
    end
  end
end
