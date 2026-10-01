# frozen_string_literal: true

require "test_helper"

# s22-list: `list` hosts a Bubbles::List sized to its panel.
class ListTest < Minitest::Test
  Fruit = Data.define(:title, :colour)

  def setup = R2UI.reset!

  def text(app, width = 40, height = 12) = app.frame(width, height).plain_lines.join("\n")

  def fruits_app(**options)
    R2UI.dashboard do
      row do
        panel :fruit, resource: nil do
          list :fruit, items: -> { state[:fruits] }, on_select: ->(item) { state[:picked] = item }, **options
        end
      end
    end
    app = R2UI::App.new(R2UI.registry)
    app.state[:fruits] = %w[apple banana cherry].map { |t| Fruit.new(title: t, colour: "red") }
    app.init
    app
  end

  def test_draws_the_items_with_its_title_sized_to_the_panel
    app = fruits_app(title: "Fruit")
    out = text(app)

    assert_match(/│Fruit/, out)
    assert_match(/│> apple/, out)
    assert_match(/│  banana/, out)
    list = app.component(:fruit)
    assert_kind_of Bubbles::List, list
    assert_equal [38, 9], [list.width, list.height], "inner size of a 40x12 frame"
  ensure
    app&.stop
  end

  def test_items_refresh_each_frame
    app = fruits_app
    text(app)
    app.state[:fruits] = [Fruit.new(title: "damson", colour: "purple")]

    out = text(app)

    assert_match(/> damson/, out)
    refute_match(/apple/, out)
  ensure
    app&.stop
  end

  def test_keys_move_the_selection_and_enter_calls_on_select
    app = fruits_app
    text(app)

    app.press(:down, :down, :up, :enter)

    assert_equal "banana", app.state[:picked].title
    assert_match(/> banana/, text(app))
  ensure
    app&.stop
  end

  def test_slash_filters_inside_the_list
    app = fruits_app
    text(app)

    app.press("/", "c", "h")
    out = text(app)
    assert_match(/Filter: ch/, out)
    assert_match(/> cherry/, out)
    refute_match(/banana/, out)
    refute_match(%r{/ch▏}, out, "the core search prompt stays closed")

    app.press(:enter) # applies the filter
    assert_nil app.state[:picked]
    app.press(:enter)
    assert_equal "cherry", app.state[:picked].title
  ensure
    app&.stop
  end

  def test_an_applied_filter_survives_new_items
    app = fruits_app
    text(app)
    app.press("/", "a", :enter)
    app.state[:fruits] += [Fruit.new(title: "date", colour: "brown"), Fruit.new(title: "fig", colour: "green")]

    out = text(app)

    assert_match(/date/, out)
    refute_match(/fig/, out)
    assert_equal Bubbles::List::FILTER_APPLIED, app.component(:fruit).filter_state
  ensure
    app&.stop
  end

  def test_filter_false_turns_filtering_off
    app = fruits_app(filter: false)
    text(app)

    app.press("/", "c")

    assert_equal Bubbles::List::UNFILTERED, app.component(:fruit).filter_state
    assert_match(/banana/, text(app))
  ensure
    app&.stop
  end

  def test_label_maps_items_to_lines_and_on_select_gets_the_item
    app = fruits_app(label: ->(fruit) { "#{fruit.title} (#{fruit.colour})" })

    assert_match(/> apple \(red\)/, text(app))
    app.press("/", "c", :enter, :enter)
    assert_equal Fruit.new(title: "cherry", colour: "red"), app.state[:picked]
  ensure
    app&.stop
  end

  def test_resource_rows
    Fixtures.define_processes
    R2UI.dashboard do
      row do
        panel :procs, resource: :process do
          list :procs, resource: :process, label: :name, on_select: ->(row) { state[:pid] = row.pid }
        end
      end
    end
    app = R2UI::App.new(R2UI.registry)
    app.feeds[:process].refresh!

    out = text(app, 40, 14)
    assert_match(/> launchd/, out)
    assert_match(/  cargo/, out)

    app.init
    app.press(:down, :enter)
    assert_equal 10, app.state[:pid]
  ensure
    app&.stop
  end

  def test_needs_a_name_and_one_source
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { row { panel(:p, resource: nil) { list(:l) } } } }
    assert_raises(ArgumentError) do
      R2UI.dashboard(:bad) { row { panel(:p, resource: nil) { list(:l, items: -> { [] }, resource: :x) } } }
    end
  end
end
