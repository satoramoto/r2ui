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

      def numeric? = Format.numeric?(format)

      def render(value) = Format.call(format, value)
    end
  end
end
