# frozen_string_literal: true

require "set"

module R2UI
  # One table line: a row, a group of rows, or a tree node with its subtree rolled up.
  Line = Data.define(:id, :label, :values, :depth, :rows, :children, :collapsed) do
    def count = rows.size
    def expandable? = children.positive?
  end

  # Turns raw rows into table lines: scope → search → group or tree → sort. Pure, so it is easy to test.
  # For a server-side resource (DSL::Resource#server?) the source did scope, search and sort already.
  class Query
    def initialize(resource, rows, scope: nil, grouping: nil, search: nil, sort: nil, collapsed: Set.new)
      @resource = resource
      @rows = rows
      @scope = scope
      @grouping = grouping
      @search = search
      @sort_key, @sort_dir = sort || resource.default_sort
      @collapsed = collapsed
      # Server-side rows come back scoped, searched and sorted: only scope blocks run here, and
      # lines (or groups, or tree siblings) keep the source's order.
      @sort_key = nil if resource.server?
    end

    def lines
      rows = @scope ? @scope.call(@rows) : @rows
      rows = Search.new(@resource, @search).call(rows) unless @resource.server?
      return sort(rows.map { |row| line_for(row) }) unless @grouping

      @grouping.tree? ? tree(rows) : groups(rows)
    end

    private

    def columns = @resource.columns

    def line_for(row)
      Line.new(id: @resource.identify(row), label: nil, values: columns.to_h { |c| [c.key, c.read(row)] },
               depth: 0, rows: [row], children: 0, collapsed: false)
    end

    def groups(rows)
      by = @grouping.by
      reader = @resource.column(by)&.method(:read) || ->(row) { Value.fetch(row, by) }
      grouped = rows.group_by(&reader)
      sort(grouped.map do |key, members|
        Line.new(id: [:group, by, key], label: key, values: aggregate(members), depth: 0, rows: members,
                 children: 0, collapsed: false)
      end)
    end

    def aggregate(rows)
      columns.to_h do |c|
        values = rows.map { |r| c.read(r) }
        value = case c.aggregate
                when :sum then values.compact.sum
                when :count then rows.size
                else values.uniq.size == 1 ? values.first : nil
                end
        [c.key, value]
      end
    end

    # Each node's summed columns hold its whole subtree; other columns hold its own value.
    def tree(rows)
      by_id = rows.to_h { |r| [@resource.identify(r), r] }
      kids = Hash.new { |h, k| h[k] = [] }
      roots = []
      rows.each do |row|
        id = @resource.identify(row)
        parent = Value.fetch(row, @resource.parent_key)
        parent != id && by_id.key?(parent) ? kids[parent] << row : roots << row
      end

      subtree = {}
      collect = lambda do |row, seen|
        id = @resource.identify(row)
        return [] unless seen.add?(id)

        subtree[id] ||= [row] + kids[id].flat_map { |k| collect.call(k, seen) }
      end

      nodes = lambda do |siblings, depth|
        lines = sort(siblings.map do |row|
          id = @resource.identify(row)
          members = subtree[id] || collect.call(row, Set.new)
          own = line_for(row).values
          values = aggregate(members).to_h { |k, v| [k, @resource.column(k).aggregate == :sum ? v : own[k]] }
          Line.new(id:, label: nil, values:, depth:, rows: members, children: kids[id].size,
                   collapsed: @collapsed.include?(id))
        end)
        lines.flat_map do |line|
          line.collapsed ? [line] : [line, *nodes.call(kids[line.id], depth + 1)]
        end
      end
      nodes.call(roots, 0)
    end

    def sort(lines)
      return lines unless @sort_key

      sorted = lines.sort_by do |line|
        v = line.values[@sort_key]
        v.nil? ? [1, 0] : [0, v.is_a?(Numeric) ? v : v.to_s.downcase]
      end
      return sorted unless @sort_dir == :desc

      present, missing = sorted.partition { |l| !l.values[@sort_key].nil? }
      present.reverse + missing
    end
  end
end
