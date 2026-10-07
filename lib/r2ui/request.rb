# frozen_string_literal: true

module R2UI
  # What a server-side source is asked for: one table panel's current view of a resource, as plain
  # data. A resource whose `source` block takes an argument gets one of these and returns the rows
  # already scoped, searched, sorted and limited (see docs/dsl.md, "Server-side fetch").
  #
  #   resource  the resource name (Symbol)
  #   scope     the selected scope's name (Symbol), or nil when the resource has no scopes
  #   search    the committed "/" text, stripped ("" for none)
  #   terms     `search` parsed: an Array of Search::Term (free text, `col~text`, `col>5`, ...)
  #   sort      [column_key, :asc | :desc], or nil
  #   limit     the resource's `limit` (Integer), or nil
  #
  # Requests compare by value, so panels showing the same view share one fetch.
  Request = Data.define(:resource, :scope, :search, :terms, :sort, :limit) do
    # The request for `resource` with that scope (a DSL::Scope or nil), search text and sort pair.
    def self.for(resource, scope: resource.default_scope, search: "", sort: resource.default_sort)
      search = search.to_s.strip
      new(resource: resource.name, scope: scope&.name, search: search.freeze,
          terms: Search.terms(resource, search).freeze, sort: sort&.dup&.freeze, limit: resource.limit)
    end

    def sort_key = sort&.first

    def sort_dir = sort&.last
  end
end
