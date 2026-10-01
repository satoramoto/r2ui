# frozen_string_literal: true

module R2UI
  module DSL
    # One attribute of a resource: how to read it, show it and roll it up.
    Column = Data.define(:key, :label, :format, :sparkline, :aggregate, :width, :align, :sort, :reader) do
      def self.build(key, label: nil, format: :text, sparkline: false, aggregate: nil, width: nil, align: nil,
                     sort: nil, &reader)
        new(
          key:, format:, sparkline:, width:, sort:, reader:,
          label: label || key.to_s.tr("_", " ").capitalize,
          aggregate: aggregate || Format.default_aggregate(format),
          align: align || Format.default_align(format)
        )
      end

      def read(row) = reader ? reader.call(row) : Value.fetch(row, key)

      # `sparkline: true` plots the history r2ui records for this column. `sparkline: :attr` (or a
      # lambda given the row) plots a series the row carries instead.
      def history_sparkline? = sparkline == true

      # The series a row carries for this column's sparkline ([] when it has none).
      def series(row)
        values = case sparkline
                 when Symbol, String then Value.fetch(row, sparkline.to_sym)
                 when Proc then sparkline.call(row)
                 end
        Array(values).map(&:to_f)
      end

      def numeric? = Format.numeric?(format)

      def render(value) = Format.call(format, value)
    end
  end
end
