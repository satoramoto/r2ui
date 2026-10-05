# frozen_string_literal: true

module R2UI
  module DSL
    # One attribute of a resource: how to read it, show it and roll it up.
    #
    # Drawing options for the index table: `style` is a callable (value, line) -> style or nil (a
    # palette Symbol or an SGR String; nil keeps the default colouring). `sparkline` is true (block
    # bars) or :braille; `spark_width` its width in cells, `spark_max` its scale (else the window
    # max), `spark_style` a style or a callable (values, line) -> style. When columns don't fit, the
    # lowest `priority` is dropped first (ties: the last declared).
    Column = Data.define(:key, :label, :format, :sparkline, :aggregate, :width, :align, :sort, :reader,
                         :style, :spark_width, :spark_max, :spark_style, :priority) do
      def self.build(key, label: nil, format: :text, sparkline: false, aggregate: nil, width: nil, align: nil,
                     sort: nil, style: nil, spark_width: nil, spark_max: nil, spark_style: nil, priority: 0, &reader)
        new(
          key:, format:, sparkline:, width:, sort:, reader:, style:, spark_width:, spark_max:, spark_style:,
          priority:,
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
