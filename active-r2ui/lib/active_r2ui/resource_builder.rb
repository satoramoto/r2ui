# frozen_string_literal: true

require "set"

module ActiveR2UI
  # r2ui's resource DSL with Rails defaults filled in for one model. Everything R2UI.resource takes
  # works here; what you don't declare is inferred:
  #
  #   source   the model's relation, newest first (integer primary key, else created_at),
  #            `limit` rows (default 500)
  #   key      the primary key
  #   index    a column per database column, formatted by type (see Columns); explicit
  #            `column`/`index` declarations replace the inferred set, and a bare `column :total`
  #            keeps the inferred format for that attribute
  #   filter   string and text columns
  #   scope    `scope :pending` with no block keeps the rows the model's `pending` scope matches
  #   action   `action :ship, key: "S"` with no block calls `record.ship` on each selected record
  #
  # Every fetch and action runs with a connection inside the Rails executor; actions are refused
  # while ActiveR2UI.read_only? (production without --allow-writes).
  class ResourceBuilder < R2UI::DSL::Resource::Builder
    def self.build(name, model, &block)
      resource = R2UI::DSL::Resource.new(name)
      builder = new(resource, model)
      builder.instance_eval(&block) if block
      builder.finish!
    end

    def initialize(resource, model)
      super(resource)
      @model = model
      @limit = DEFAULT_LIMIT
      @memberships = {} # named scope => Set of primary key values in the last fetch
      @columns_declared = false
      @filter_declared = false
      title(model.model_name.human.pluralize)
      refresh(every: DEFAULT_REFRESH)
      key(default_key) if default_key
      source { default_relation.limit(@limit).to_a }
    end

    # How many rows each fetch loads (newest first). Ignored when you give your own `source`.
    def limit(rows) = @limit = Integer(rows)

    # The model this resource shows.
    attr_reader :model

    def column(key, **options, &reader)
      @columns_declared = true
      spec = !reader && !options.key?(:format) && Columns.spec(@model, key)
      if spec
        options = spec.options.merge(options)
        reader = spec.reader
      end
      super(key, **options, &reader)
    end
    alias attribute column

    def filter(*keys)
      @filter_declared = true
      super
    end

    # No block: the model's scope (or class method) of that name, applied to the fetched rows.
    def scope(name, label: nil, default: false, &filter)
      filter ||= named_scope(name) unless name.to_sym == :all
      super(name, label:, default:, &filter)
    end

    # No block: calls the model method of that name on each selected record.
    def action(name, key:, label: nil, confirm: false, &handler)
      handler ||= ->(record) { record.public_send(name) }
      super(name, key:, label:, confirm:, &ActiveR2UI.guard(@model, handler))
    end

    # Fills what the block didn't declare, wraps the source in a connection, validates.
    def finish!
      unless @columns_declared
        Columns.infer(@model).each { |spec| @r.columns << R2UI::DSL::Column.build(spec.key, **spec.options, &spec.reader) }
      end
      filter(*Columns.searchable(@model)) unless @filter_declared
      wrap_source
      @r.validate!
    end

    private

    def default_key
      pk = @model.primary_key
      return nil if pk.nil?

      pk.is_a?(Array) ? :id : pk.to_sym
    end

    # Newest first: by an integer primary key, else by created_at when there is one (UUID and
    # string keys don't sort by age), else by the primary key.
    def default_relation
      pk = @model.primary_key
      columns = @model.columns_hash
      integer_pk = pk.is_a?(String) && %i[integer bigint].include?(columns[pk]&.type)
      order = if integer_pk || (pk && !columns.key?("created_at")) then Array(pk)
              elsif columns.key?("created_at") then ["created_at", *pk]
              end
      order ? @model.reorder(order.to_h { |column| [column, :desc] }) : @model.all
    end

    def named_scope(name)
      unless @model.respond_to?(name)
        raise Error, "#{@model.name} has no scope or class method :#{name} (give `scope :#{name}` a block)"
      end

      @memberships[name] = Set.new
      lambda do |row|
        members = @memberships[name]
        members.include?(row.respond_to?(:id) ? row.id : row)
      end
    end

    # Runs the source with a connection (and in the executor), materialises the rows there, and
    # records which of them each blockless named scope matches.
    def wrap_source
      inner = @r.source
      model = @model
      set(:source, lambda do
        ActiveR2UI.with_connection(model) do
          rows = inner.call
          rows = rows.respond_to?(:to_ary) ? rows.to_ary : Array(rows)
          refresh_memberships(rows)
          rows
        end
      end)
    end

    def refresh_memberships(rows)
      return if @memberships.empty?

      pk = @model.primary_key
      ids = rows.filter_map { |row| row.id if row.is_a?(@model) }
      @memberships = @memberships.keys.to_h do |name|
        relation = @model.public_send(name)
        unless relation.is_a?(ActiveRecord::Relation)
          raise Error, "#{@model.name}.#{name} returned #{relation.class}, not a relation"
        end

        [name, ids.empty? ? Set.new : relation.where(pk => ids).pluck(pk).to_set]
      end
    end
  end
end
