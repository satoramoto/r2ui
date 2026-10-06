# frozen_string_literal: true

module R2UI
  # The "/" search. Space-separated terms, all must match:
  #   codex          free text, case-insensitive, against the resource's `filter` attributes
  #   cpu>5          comparison on a column, operand parsed by its format ("mem>=500M")
  #   cwd~starseed   substring match on one column
  class Search
    TERM = /\A(?<field>\w+)(?<op>>=|<=|!=|>|<|=|~)(?<operand>.+)\z/
    OPS = { ">" => :>, "<" => :<, ">=" => :>=, "<=" => :<=, "=" => :==, "!=" => :!=, "~" => :contains }.freeze

    # One parsed search term, plain data (server-side sources get these as Request#terms).
    #   text    the term as typed ("cpu>5")
    #   op      :match (free text), :contains (`~`), or a comparison: :>, :<, :>=, :<=, :==, :!=
    #   field   the column key compared, or nil for free text
    #   fields  the attributes the term looks at: the `filter` attributes (or the text columns) for
    #           free text, [field] otherwise
    #   value   free text and `~`: the text as typed; comparisons: the operand parsed by the
    #           column's format (nil when it doesn't parse; such a term matches nothing)
    Term = Data.define(:text, :op, :field, :fields, :value) do
      def free_text? = op == :match
    end

    # The terms of `text` for `resource`.
    def self.terms(resource, text)
      text.to_s.split.map do |term|
        m = TERM.match(term)
        column = m && resource.column(m[:field].to_sym)
        next Term.new(text: term, op: :match, field: nil, fields: free_text_keys(resource), value: term) unless column

        op = OPS.fetch(m[:op])
        value = op == :contains ? m[:operand] : Format.parse(column.format, m[:operand])
        Term.new(text: term, op:, field: column.key, fields: [column.key], value:)
      end
    end

    def self.free_text_keys(resource)
      resource.searchable.any? ? resource.searchable : resource.columns.reject(&:numeric?).map(&:key)
    end

    def initialize(resource, text)
      @resource = resource
      @predicates = Search.terms(resource, text).map { |term| predicate(term) }
    end

    def call(rows) = @predicates.empty? ? rows : rows.select { |row| @predicates.all? { |p| p.call(row) } }

    private

    def predicate(term)
      return free_text(term) if term.free_text?

      compare(@resource.column(term.field), term.op, term.value)
    end

    def free_text(term)
      needle = term.value.downcase
      readers = term.fields.map { |k| @resource.column(k)&.method(:read) || ->(row) { Value.fetch(row, k) } }
      ->(row) { readers.any? { |read| read.call(row).to_s.downcase.include?(needle) } }
    end

    def compare(column, op, target)
      return ->(row) { column.read(row).to_s.downcase.include?(target.downcase) } if op == :contains
      return ->(_) { false } if target.nil?

      target = target.downcase if target.is_a?(String)
      lambda do |row|
        value = column.read(row)
        value = value.to_s.downcase if target.is_a?(String)
        value.public_send(op, target)
      rescue ArgumentError, NoMethodError
        false
      end
    end
  end
end
