# frozen_string_literal: true

require "test_helper"

# s27-paginator: `paginate` shows one page of lines plus a Bubbles::Paginator.
class PaginatorTest < Minitest::Test
  def setup
    R2UI.reset!
    R2UI::Component.require_bubbles!
    @items = (1..25).to_a
  end

  def teardown = @app&.stop

  # One panel (focused) holding a paginator over @items; a second panel to move focus to.
  def build(type: nil, per_page: 10)
    items = -> { @items }
    options = { items:, per_page: }
    options[:type] = type if type
    R2UI.dashboard do
      row do
        panel :pages, resource: nil do
          paginate :list, **options do |item|
            "item #{item}"
          end
        end
        panel :other, resource: nil do
          view { "other" }
        end
      end
    end
    @app = R2UI::App.new(R2UI.registry)
    @app.focus = @app.dashboard.panels.first
    @app.init
    @app
  end

  def text(width = 40, height = 16) = @app.frame(width, height).plain_lines.join("\n")

  def shown = text.scan(/item (\d+)/).flatten.map(&:to_i)

  def test_shows_only_the_first_page_of_lines
    build
    assert_equal (1..10).to_a, shown
  end

  def test_hosts_a_bubbles_paginator_sized_to_the_items
    build
    text
    paginator = @app.component(:list)

    assert_kind_of Bubbles::Paginator, paginator
    assert_equal 10, paginator.per_page
    assert_equal 3, paginator.total_pages
    assert_equal 0, paginator.page
  end

  def test_dots_are_the_default_indicator
    build
    assert_includes text, "● ○ ○"
  end

  def test_arabic_type_shows_page_numbers
    build(type: :arabic)
    assert_includes text, "1/3"
    refute_includes text, "●"
  end

  def test_right_key_shows_the_next_page
    build
    @app.press(:right)
    assert_equal (11..20).to_a, shown
    assert_includes text, "○ ● ○"
  end

  def test_l_key_shows_the_next_page
    build
    @app.press("l")
    assert_equal (11..20).to_a, shown
  end

  def test_left_and_h_keys_go_back
    build
    @app.press(:right, :right)
    @app.press(:left)
    assert_equal (11..20).to_a, shown
    @app.press("h")
    assert_equal (1..10).to_a, shown
  end

  def test_last_page_is_the_short_remainder
    build
    @app.press(:right, :right)
    assert_equal (21..25).to_a, shown
  end

  def test_paging_stops_at_both_ends
    build
    @app.press(:left)
    assert_equal (1..10).to_a, shown
    @app.press(:right, :right, :right, :right)
    assert_equal (21..25).to_a, shown
  end

  def test_keys_do_nothing_while_another_panel_is_focused
    build
    @app.press(:tab)
    @app.press(:right)
    assert_equal (1..10).to_a, shown
  end

  def test_items_are_read_on_every_frame
    build
    @app.press(:right, :right)
    @items = (1..12).to_a

    assert_equal [11, 12], shown, "the page is clamped when the list shrinks"
    assert_equal 2, @app.component(:list).total_pages
  end

  def test_per_page_sets_the_page_size
    build(per_page: 4)
    assert_equal (1..4).to_a, shown
    assert_equal 7, @app.component(:list).total_pages
  end

  def test_an_empty_list_is_one_empty_page
    @items = []
    build
    assert_empty shown
    assert_equal 1, @app.component(:list).total_pages
  end

  def test_needs_items_and_a_block
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { row { panel(:p, resource: nil) { paginate(:x) { |i| i } } } } }
    assert_raises(ArgumentError) do
      R2UI.dashboard(:bad) { row { panel(:p, resource: nil) { paginate(:x, items: -> { [] }) } } }
    end
  end
end
