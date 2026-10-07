# frozen_string_literal: true

module ActiveR2UI
  # Index columns inferred from a model's `columns_hash`: format and reader by database type, and a
  # priority so narrow terminals drop timestamps, foreign keys and long text before names.
  module Columns
    # Column options (format:, priority:, label:, width:) plus a reader, or nil for a skipped type.
    Spec = Data.define(:key, :options, :reader)

    SKIPPED = %i[json jsonb binary blob hstore].freeze
    TEXT_LIMIT = 200
    NAME_LIKE = %w[name title email slug label subject username login].freeze

    module_function

    def infer(model)
      model.columns_hash.each_value.filter_map { |column| spec(model, column.name) }
    end

    # The inferred spec for one attribute of `model`, or nil (unknown attribute or skipped type).
    def spec(model, attribute)
      column = model.columns_hash[attribute.to_s] or return nil
      type = column.type
      return nil if SKIPPED.include?(type)

      name = column.name
      format, priority, convert = shape(model, column, type)
      return nil unless format

      options = { format:, priority:, label: model.human_attribute_name(name) }
      options[:width] = 13 if type == :uuid
      convert = ->(v) { Decimal.wrap(v, column.scale) } if convert == :decimal
      Spec.new(key: name.to_sym, options:, reader: reader(name, convert))
    end

    # Text columns: what free-text search ("/") matches.
    def searchable(model)
      model.columns_hash.each_value.select { |c| %i[string text citext].include?(c.type) }.map { |c| c.name.to_sym }
    end

    def shape(model, column, type)
      name = column.name
      return [:text, 25, :text] if column.respond_to?(:array?) && column.array?
      return [:id, 100, nil] if primary_key?(model, name) && %i[integer bigint].include?(type)
      return [:id, 20, nil] if foreign_key?(model, name) && %i[integer bigint].include?(type)

      case type
      when :integer, :bigint then [:integer, 50, nil]
      when :decimal, :float then [:number, 50, :decimal]
      when :boolean then [:text, 40, :boolean]
      when :datetime, :timestamp, :timestamptz, :date then [:text, timestamp_priority(name), :timestamp]
      when :time then [:text, 30, :time]
      when :text then [:text, 15, :text]
      when :uuid then [:text, primary_key?(model, name) ? 100 : 20, :text]
      else [:text, NAME_LIKE.include?(name) ? 80 : 60, :text]
      end
    end

    def reader(name, convert)
      convert = CONVERT.fetch(convert) if convert.is_a?(Symbol)
      lambda do |row|
        value = row.respond_to?(:read_attribute) ? row.read_attribute(name) : R2UI::Value.fetch(row, name.to_sym)
        convert ? convert.call(value) : value
      end
    end

    CONVERT = {
      boolean: ->(v) { v.nil? ? nil : (v ? "yes" : "no") },
      timestamp: ->(v) { Timestamp.wrap(v) },
      time: ->(v) { v&.strftime("%H:%M:%S") },
      text: lambda do |v|
        next nil if v.nil?

        text = (v.is_a?(Array) ? v.join(", ") : v.to_s).gsub(/\s+/, " ").strip
        text.length > TEXT_LIMIT ? "#{text[0, TEXT_LIMIT - 1]}…" : text
      end
    }.freeze

    def timestamp_priority(name)
      case name
      when "updated_at" then 10
      when "created_at" then 30
      else 35
      end
    end

    def primary_key?(model, name) = Array(model.primary_key).include?(name)

    def foreign_key?(model, name)
      name.end_with?("_id") ||
        model.reflect_on_all_associations(:belongs_to).any? { |a| a.foreign_key.to_s == name }
    end
  end
end
