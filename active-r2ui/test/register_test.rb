# frozen_string_literal: true

require "test_helper"

module ActiveR2UI
  class RegisterTest < TestCase
    def app(screen = :orders) = R2UI::App.new(R2UI.registry, screen)

    def test_defaults_show_newest_first_with_inferred_columns
      seed_orders
      ActiveR2UI.register(Order)
      resource = R2UI.registry.resource(:orders)
      assert_equal "Orders", resource.title
      assert_equal :id, resource.key
      assert_includes resource.columns.map(&:key), :total
      text = frame(app)
      assert_match(/Status/, text)
      assert_match(/12\.5/, text)
      statuses = text.lines.grep(/pending|shipped/).map { |l| l[/pending|shipped/] }
      assert_equal %w[pending shipped pending], statuses # ids 3, 2, 1
    end

    def test_limit_caps_the_fetch
      seed_orders
      ActiveR2UI.register(Order) { limit 2 }
      rows = R2UI.registry.resource(:orders).fetch
      assert_equal Order.order(id: :desc).limit(2).pluck(:id), rows.map(&:id)
    end

    def test_search_matches_text_columns
      seed_orders
      ActiveR2UI.register(Order)
      a = app
      frame(a)
      a.press("/", *"shipped".chars, :enter)
      text = a.frame(140, 20).plain_lines.join("\n")
      assert_match(/shipped/, text)
      refute_match(/pending/, text.lines.reject { |l| l.include?("/shipped") }.join)
    end

    def test_explicit_columns_replace_inferred_ones_and_keep_type_formats
      seed_orders
      ActiveR2UI.register(Order) do
        index do
          column :status
          column :total
          column(:who) { |o| o.customer&.name }
        end
      end
      columns = R2UI.registry.resource(:orders).columns
      assert_equal %i[status total who], columns.map(&:key)
      assert_equal :number, columns[1].format
    end

    def test_blockless_scope_calls_the_named_scope
      seed_orders
      ActiveR2UI.register(Order) do
        scope :all
        scope :pending, default: true
      end
      resource = R2UI.registry.resource(:orders)
      rows = resource.fetch
      pending = resource.scopes.find { |s| s.name == :pending }
      assert_equal Order.pending.order(id: :desc).pluck(:id), pending.call(rows).map(&:id)
      assert_equal 3, resource.scopes.first.call(rows).size
    end

    def test_unknown_scope_is_an_error
      error = assert_raises(Error) { ActiveR2UI.register(Order) { scope :nope } }
      assert_match(/no scope or class method :nope/, error.message)
    end

    def test_blockless_action_calls_the_model_method
      seed_orders
      ActiveR2UI.register(Order) { action :ship, key: "x" }
      a = app
      frame(a)
      a.press("x")
      assert_equal "shipped", Order.order(:id).last.status
    end

    def test_actions_are_refused_when_read_only
      seed_orders
      ActiveR2UI.register(Order) { action :ship, key: "x" }
      ActiveR2UI.read_only = true
      a = app
      frame(a)
      a.press("x")
      assert_equal "pending", Order.order(:id).last.status
      assert_match(/read-only in production/, a.frame(140, 20).plain_lines.join("\n"))
    end

    def test_models_without_a_primary_key_have_no_key
      Event.create!(kind: "boot")
      ActiveR2UI.register(Event)
      assert_nil R2UI.registry.resource(:events).key
      assert_match(/boot/, frame(app(:events)))
    end

    def test_fetch_errors_show_in_the_panel
      ActiveR2UI.register(Order) { source { raise "database is down" } }
      assert_match(/database is down/, frame(app))
    end

    def test_fetches_from_feed_threads_return_their_connections
      seed_orders
      ActiveR2UI.register(Order)
      feed = R2UI::Feed.new(R2UI.registry.resource(:orders))
      Thread.new { 3.times { feed.refresh! } }.join
      assert_nil feed.error
      assert_equal 3, feed.rows.size
      assert_equal 0, Order.connection_pool.stat[:busy] - (Order.connection_pool.active_connection? ? 1 : 0)
    end

    def test_string_primary_keys_order_newest_first_by_created_at
      Token.create!(id: "zzz", created_at: Time.now - 60)
      Token.create!(id: "aaa", created_at: Time.now)
      ActiveR2UI.register(Token)
      assert_equal %w[aaa zzz], R2UI.registry.resource(:tokens).fetch.map(&:id)
    end

    def test_discover_skips_abstract_sti_and_tableless_models
      assert_equal %w[Customer Event Order Token], ActiveR2UI.discover.map(&:name)
    end
  end
end
