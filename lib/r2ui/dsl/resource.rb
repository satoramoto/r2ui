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

    Action = Data.define(:name, :label, :key, :confirm, :handler)

    # A resource definition. Built by Resource::Builder from the block given to R2UI.resource.
    class Resource
      attr_reader :name, :title, :source, :interval, :key, :parent_key, :scopes, :groupings, :columns,
                  :searchable, :actions, :limit

      def self.build(name, &block)
        resource = new(name)
        Builder.new(resource).instance_eval(&block) if block
        resource.validate!
      end

      def initialize(name)
        @name = name.to_sym
        @title = name.to_s.tr("_", " ").capitalize
        @interval = 1.0
        @scopes = []
        @groupings = []
        @columns = []
        @searchable = []
        @actions = []
        @declarations = Hash.new { |h, k| h[k] = [] }
      end

      # What extensions declared on this resource, by key.
      attr_reader :declarations

      def declared(key) = declarations.fetch(key, [])

      def column(key) = columns.find { |c| c.key == key }

      def default_scope = scopes.find(&:default) || scopes.first

      def default_sort
        col = columns.find(&:sort)
        col ? [col.key, col.sort] : nil
      end

      # Server-side fetch: the `source` block takes an argument (an R2UI::Request) and returns the
      # rows already scoped, searched, sorted and limited.
      def server? = !source.arity.zero?

      # Calls the source: with a request when it is server-side (the default view if none given).
      def fetch(request = nil)
        rows = server? ? source.call(request || Request.for(self)) : source.call
        rows.respond_to?(:to_ary) ? rows.to_ary : [rows]
      end

      def identify(row) = key ? Value.fetch(row, key) : row.object_id

      def validate!
        raise Error, "resource #{name} needs a `source { ... }` block" unless source
        if limit && !server?
          raise Error, "resource #{name}: `limit` needs a server-side source (`source { |request| ... }`)"
        end
        if groupings.any?(&:tree?) && !(key && parent_key)
          raise Error, "resource #{name}: tree grouping needs `key :id_attr, parent: :parent_attr`"
        end

        self
      end

      # The DSL. Each method records a declaration on the resource.
      class Builder
        def initialize(resource) = @r = resource

        def title(text) = set(:title, text)

        # `source { rows }` fetches everything and r2ui scopes, searches and sorts in memory.
        # `source { |request| rows }` is server-side: it gets an R2UI::Request (scope, search,
        # terms, sort, limit) and returns just those rows, in order.
        def source(&block) = set(:source, block)

        # Server-side sources: the most rows one request asks for (Request#limit).
        def limit(count) = set(:limit, Integer(count))

        # `every:` takes seconds, or anything with #to_f (an ActiveSupport::Duration).
        def refresh(every:) = set(:interval, every.to_f)

        # Which attribute identifies a row, and optionally which points at its parent row.
        def key(attr, parent: nil)
          set(:key, attr)
          set(:parent_key, parent)
        end

        # With a server-side source, a scope without a block is applied by the source (it gets the
        # name as Request#scope); a block still filters the returned rows in memory.
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

        def action(name, key:, label: nil, confirm: false, &handler)
          @r.actions << Action.new(name:, label: label || humanize(name), key:, confirm:, handler:)
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
