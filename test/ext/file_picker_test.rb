# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

# s31-file-picker: the `file_picker` panel keyword hosts a Bubbles::FilePicker. Expected
# behavior comes from bubbles itself (navigation keys, what is selectable); these tests pin
# how r2ui hosts it: keys while focused, on_select, the allowed list, sizing to the panel.
class FilePickerTest < Minitest::Test
  def setup
    R2UI.reset!
    @dir = File.realpath(Dir.mktmpdir("r2ui-file-picker"))
    FileUtils.mkdir_p(File.join(@dir, "sub"))
    %w[a.rb b.rb c.txt sub/d.rb].each { |f| File.write(File.join(@dir, f), "x") }
    @selected = []
  end

  def teardown = FileUtils.remove_entry(@dir)

  def build(allowed: %w[.rb], dir: @dir, height: nil)
    picked = @selected
    R2UI.dashboard do
      row height: height do
        panel :files, resource: nil do
          file_picker :browser, dir: dir, allowed: allowed, on_select: ->(path) { picked << path }
        end
      end
    end
    @app = R2UI::App.new(R2UI.registry)
  end

  def text(width = 60, height = 14) = @app.frame(width, height).plain_lines.join("\n")

  # Entries sort directories first, then by name: sub/, a.rb, b.rb, c.txt.
  def test_hosts_a_bubbles_file_picker_on_the_given_directory
    build
    picker = @app.component(:browser)

    assert_kind_of Bubbles::FilePicker, picker
    assert_equal @dir, picker.current_directory
  end

  def test_draws_the_directory_listing_in_the_panel
    build
    out = text

    assert_match(/sub\//, out)
    assert_match(/a\.rb/, out)
    assert_match(/c\.txt/, out)
    assert_match(/>/, out, "the cursor")
  end

  def test_down_and_enter_selects_a_file_and_calls_on_select_with_its_path
    build
    @app.init
    @app.press(:down, :enter)

    assert_equal [File.join(@dir, "a.rb")], @selected
  end

  def test_on_select_fires_once_per_selection
    build
    @app.init
    @app.press(:down, :enter)
    @app.press(:down)

    assert_equal 1, @selected.size
  end

  def test_enter_on_a_directory_navigates_into_it_without_selecting
    build
    @app.init
    @app.press(:enter)

    assert_empty @selected
    assert_equal File.join(@dir, "sub"), @app.component(:browser).current_directory
    assert_match(/d\.rb/, text)
  end

  def test_left_goes_back_up_after_entering_a_directory
    build
    @app.init
    @app.press(:enter, :left)

    assert_equal @dir, @app.component(:browser).current_directory
  end

  def test_files_outside_allowed_cannot_be_selected
    build(allowed: %w[.rb])
    @app.init
    @app.press(:down, :down, :down, :enter)

    assert_empty @selected
  end

  def test_allowed_may_be_given_with_or_without_the_dot
    build(allowed: %w[txt])
    @app.init
    @app.press(:down, :down, :down, :enter)

    assert_equal [File.join(@dir, "c.txt")], @selected
  end

  def test_empty_allowed_selects_any_file
    build(allowed: [])
    @app.init
    @app.press(:down, :down, :down, :enter)

    assert_equal [File.join(@dir, "c.txt")], @selected
  end

  def test_keys_go_to_the_picker_while_its_panel_has_focus_not_the_core
    build
    @app.init
    commands = @app.press("j", "k")

    refute(commands.any? { |c| c.is_a?(Bubbletea::QuitCommand) })
    assert_equal 0, @app.component(:browser).cursor
    @app.press("j")
    assert_equal 1, @app.component(:browser).cursor
  end

  def test_view_is_clipped_to_the_panel_and_follows_the_cursor
    many = Dir.mktmpdir("r2ui-file-picker-many")
    (1..30).each { |i| File.write(File.join(many, format("f%02d.rb", i)), "x") }
    build(dir: many)
    @app.init
    out = text(50, 10)
    assert_match(/f01\.rb/, out)
    refute_match(/f30\.rb/, out)
    assert(out.lines.size <= 10)

    @app.press("G")
    out = text(50, 10)

    assert_match(/f30\.rb/, out, "the cursor row stays visible in a panel shorter than the listing")
    assert(out.lines.size <= 10)
  ensure
    FileUtils.remove_entry(many) if many
  end

  def test_needs_a_name_and_on_select_optional
    assert_raises(ArgumentError) do
      R2UI.dashboard(:bad) { row { panel(:p, resource: nil) { file_picker } } }
    end
    R2UI.dashboard(:ok) { row { panel(:p, resource: nil) { file_picker :browser, dir: "." } } }
    assert_kind_of Bubbles::FilePicker, R2UI::App.new(R2UI.registry).component(:browser)
  end
end
