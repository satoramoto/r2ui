# frozen_string_literal: true

module Paneful
  # The "/" search. Space-separated terms, all must match:
  #   codex          free text, case-insensitive, against the resource's `filter` attributes
  #   cpu>5          comparison on a column, operand parsed by its format ("mem>=500M")
  #   cwd~starseed   substring match on one column
  class Search
    TERM = /\A(?<field>\w+)(?<op>>=|<=|!=|>|<|=|~)(?<operand>.+)\z/

    def initialize(resource, text)
      @resource = resource
      @predicates = text.to_s.split.map { |term| predicate(term) }
    end

    def call(rows) = @predicates.empty? ? rows : rows.select { |row| @predicates.all? { |p| p.call(row) } }

    private

    def predicate(term)
      m = TERM.match(term)
      column = m && @resource.column(m[:field].to_sym)
      return free_text(term) unless column

      compare(column, m[:op], m[:operand])
    end

    def free_text(term)
      needle = term.downcase
      keys = @resource.searchable.any? ? @resource.searchable : text_columns
      readers = keys.map { |k| @resource.column(k)&.method(:read) || ->(row) { Value.fetch(row, k) } }
      ->(row) { readers.any? { |read| read.call(row).to_s.downcase.include?(needle) } }
    end

    def compare(column, op, operand)
      return ->(row) { column.read(row).to_s.downcase.include?(operand.downcase) } if op == "~"

      target = Format.parse(column.format, operand)
      return ->(_) { false } if target.nil?

      lambda do |row|
        value = column.read(row)
        value = value.to_s.downcase if target.is_a?(String)
        target = target.downcase if target.is_a?(String)
        case op
        when ">" then value > target
        when "<" then value < target
        when ">=" then value >= target
        when "<=" then value <= target
        when "=" then value == target
        when "!=" then value != target
        end
      rescue ArgumentError, NoMethodError
        false
      end
    end

    def text_columns = @resource.columns.reject(&:numeric?).map(&:key)
  end
end
