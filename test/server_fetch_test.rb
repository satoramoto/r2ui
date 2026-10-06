# frozen_string_literal: true

require "test_helper"

# Server-side fetch: a `source` block that takes an R2UI::Request returns rows already scoped,
# searched, sorted and limited; r2ui refetches when a panel's view changes and only groups in memory.
class ServerFetchTest < Minitest::Test
  Order = Data.define(:id, :customer, :status, :total)

  ORDERS = [
    Order.new(id: 1, customer: "ada", status: "pending", total: 5),
    Order.new(id: 2, customer: "bob", status: "shipped", total: 50),
    Order.new(id: 3, customer: "foo", status: "pending", total: 20),
    Order.new(id: 4, customer: "food", status: "shipped", total: 1),
    Order.new(id: 5, customer: "ada", status: "pending", total: 70)
  ].freeze

  # A fake database: records each request, answers it like a query would.
  class FakeTable
    attr_reader :requests
    attr_accessor :fail

    def initialize = @requests = []

    def call(request)
      @requests << request
      raise "connection refused" if fail

      rows = ORDERS
      rows = rows.select { |o| o.status == request.scope.to_s } if %i[pending shipped].include?(request.scope)
      request.terms.each do |term|
        rows = if term.free_text?
                 rows.select { |o| term.fields.any? { |f| o.public_send(f).to_s.include?(term.value) } }
               else
                 rows.select { |o| o.public_send(term.field).public_send(term.op, term.value) }
               end
      end
      if request.sort
        rows = rows.sort_by { |o| o.public_send(request.sort_key) }
        rows = rows.reverse if request.sort_dir == :desc
      end
      rows.first(request.limit || rows.size)
    end
  end

  def setup
    R2UI.reset!
    @table = table = FakeTable.new
    R2UI.resource :order do
      source { |request| table.call(request) }
      limit 4
      key :id
      scope :all, default: true
      scope :pending
      scope(:big) { |o| o.total >= 20 }
      group_by :status
      index do
        column :id, format: :id
        column :customer
        column :status
        column :total, format: :number, sort: :desc
      end
      filter :customer
    end
  end

  def dashboard(&block)
    R2UI.dashboard(&block || proc { row { panel :order } })
    @app = R2UI::App.new(R2UI.registry)
    @app.snapshot(width: 100, height: 20)
    @app
  end

  def text = @app.frame(100, 20).plain_lines.join("\n")

  def ids(panel = @app.focus) = @app.frame(100, 20) && @app.panel_lines(panel).map { |l| l.values[:id] }

  # Runs the background commands a key press returned, as the runner would.
  def perform(commands) = Array(commands).each { |cmd| cmd.call }

  def test_source_gets_the_default_request_and_its_rows_are_shown_in_source_order
    dashboard
    request = @table.requests.last
    assert_equal :order, request.resource
    assert_equal :all, request.scope
    assert_equal "", request.search
    assert_equal [], request.terms
    assert_equal [:total, :desc], request.sort
    assert_equal 4, request.limit
    assert_equal [5, 2, 3, 1], ids, "the source's rows, limited and in its order"
    assert_match(/sort: Total▼/, text)
  end

  def test_scope_change_refetches_with_the_new_scope
    dashboard
    commands = @app.press("]")
    assert_equal 1, commands.size, "one fetch for the new request"
    perform(commands)
    assert_equal :pending, @table.requests.last.scope
    assert_equal [5, 3, 1], ids
    assert_match(/\[Pending\]/, text)
  end

  def test_search_refetches_on_enter_not_while_typing
    dashboard
    before = @table.requests.size
    assert_empty @app.press("/", "f", "o", "o"), "typing doesn't fetch"
    assert_equal "", @app.panel_request(@app.focus).search
    commands = @app.press(:enter)
    perform(commands)
    assert_equal before + 1, @table.requests.size
    request = @table.requests.last
    assert_equal "foo", request.search
    assert_equal [R2UI::Search::Term.new(text: "foo", op: :match, field: nil, fields: [:customer], value: "foo")],
                 request.terms
    assert_equal [3, 4], ids, "rows the source returned; not searched again in memory"

    perform(@app.press("/", :escape))
    assert_equal "", @table.requests.last.search
    assert_equal [5, 2, 3, 1], ids
  end

  def test_comparison_terms_are_parsed_by_column_format
    dashboard
    perform(@app.press("/", *"total>=20 status~ship".chars, :enter))
    terms = @table.requests.last.terms
    assert_equal [:>=, :contains], terms.map(&:op)
    assert_equal [20, "ship"], terms.map(&:value)
    assert_equal %i[total status], terms.map(&:field)
  end

  def test_sort_keys_refetch_with_the_new_sort
    dashboard
    perform(@app.press("s"))
    assert_equal [:id, :asc], @table.requests.last.sort
    assert_equal [1, 2, 3, 4], ids
    perform(@app.press("S"))
    assert_equal [:id, :desc], @table.requests.last.sort
    assert_equal [5, 4, 3, 2], ids
  end

  def test_same_request_does_not_refetch_and_grouping_runs_on_returned_rows
    dashboard
    assert_empty @app.press("g"), "grouping is not part of the request"
    assert_match(/group: Status/, text)
    lines = @app.panel_lines(@app.focus)
    assert_equal %w[pending shipped], lines.map(&:label), "groups in the order the source's rows came"
    assert_equal [3, 1], lines.map(&:count)
  end

  def test_scope_block_still_filters_in_memory
    dashboard
    perform(@app.press("]", "]"))
    assert_equal :big, @table.requests.last.scope
    assert_equal [5, 2, 3], ids, "the source ignored :big; its block filtered the rows"
  end

  def test_a_late_response_for_an_old_search_never_replaces_the_new_one
    dashboard
    old = @app.press("/", "a", :enter)
    new = @app.press("/", :backspace, "f", "o", "o", :enter)
    perform(new)
    perform(old)
    assert_equal "foo", @app.panel_request(@app.focus).search
    assert_equal [3, 4], ids
  end

  def test_a_slower_older_fetch_of_the_same_request_is_dropped
    dashboard
    feed = @app.feeds[:order]
    request = @app.panel_request(@app.focus)
    gate = Queue.new
    calls = 0
    rows = [[ORDERS[0]], [ORDERS[1]]]
    R2UI.registry.resource(:order).instance_variable_set(:@source, lambda do |_req|
      calls += 1
      n = calls
      gate.pop if n == 1
      rows[n - 1]
    end)
    slow = Thread.new { feed.fetch(request) }
    Thread.pass until calls == 1
    assert feed.fetch(request), "the newer fetch lands"
    gate << :go
    refute slow.value, "the older one finishing later is dropped"
    assert_equal [2], ids
  end

  def test_rows_stay_until_the_new_request_answers
    dashboard
    @app.press("]")
    assert_equal [5, 2, 3, 1], ids, "pending fetch: the panel keeps what it showed"
  end

  def test_panels_with_different_views_get_their_own_requests
    dashboard do
      row do
        panel :order
        panel :pending, resource: :order do
          table scope: :pending
        end
      end
    end
    all, pending = @app.dashboard.panels
    assert_equal %i[all pending], @table.requests.map(&:scope).uniq.sort
    assert_equal [5, 2, 3, 1], ids(all)
    assert_equal [5, 3, 1], ids(pending)
    assert_equal [5, 2, 3, 1], @app.feeds[:order].rows.map(&:id), "feed.rows: the focused panel's request"

    # Moving the first panel to :pending shares the other panel's request: nothing new to fetch.
    assert_empty @app.press("]")
    assert_equal [5, 3, 1], ids(all)
  end

  def test_fetch_errors_show_in_the_panel
    @table.fail = true
    dashboard
    assert_match(/RuntimeError: connection refused/, text)
  end

  def test_zero_argument_sources_stay_in_memory
    R2UI.resource(:plain) { source { [] } }
    refute R2UI.registry.resource(:plain).server?
    assert R2UI.registry.resource(:order).server?
    error = assert_raises(R2UI::Error) { R2UI.resource(:capped) { source { [] } ; limit 5 } }
    assert_match(/limit/, error.message)
  end
end
