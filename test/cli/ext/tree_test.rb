# frozen_string_literal: true

require "minitest/autorun"
require "r2ui/cli/testing"

class CLITreeTest < Minitest::Test
  include R2UI::CLI::Testing

  CLI = R2UI::CLI
  ESC = /\e\[[\d;]*m/

  DEPS = { "rails@7.1" => { "rack@3.0" => nil, "activesupport@7.1" => { "i18n@1.14" => nil } },
           "pg@1.5" => nil }.freeze

  def with_ansi
    R2UI::Compat::Gloss::Renderer.color_profile = :ansi
    yield
  ensure
    R2UI::Compat::Gloss::Renderer.color_profile = nil
  end

  def printed(**shell_options, &block) = with_shell(**shell_options, &block).last.output.string

  # ---- plain (pipe) output ----

  def test_the_story_example
    out = printed { CLI.tree("app@1.0", { "rails@7.1" => { "rack@3.0" => nil }, "pg@1.5" => nil }) }
    assert_equal <<~TREE, out
      app@1.0
      ├── rails@7.1
      │   └── rack@3.0
      └── pg@1.5
    TREE
  end

  def test_deeper_nesting_keeps_the_rails
    out = printed { CLI.tree("app@1.0", DEPS) }
    assert_equal <<~TREE, out
      app@1.0
      ├── rails@7.1
      │   ├── rack@3.0
      │   └── activesupport@7.1
      │       └── i18n@1.14
      └── pg@1.5
    TREE
  end

  def test_arrays_of_leaves_and_hashes
    out = printed { CLI.tree("src", ["main.rb", { "lib" => ["a.rb", "b.rb"] }, "README.md"]) }
    assert_equal <<~TREE, out
      src
      ├── main.rb
      ├── lib
      │   ├── a.rb
      │   └── b.rb
      └── README.md
    TREE
  end

  def test_an_array_inside_an_array_nests_under_the_item_before_it
    out = printed { CLI.tree("root", ["a", %w[a1 a2], "b"]) }
    assert_equal <<~TREE, out
      root
      ├── a
      │   ├── a1
      │   └── a2
      └── b
    TREE
  end

  def test_a_single_value_is_one_child_and_leaves_become_strings
    out = printed { CLI.tree(:app, { "web" => "nginx", 42 => nil, sym: [1.5] }) }
    assert_equal <<~TREE, out
      app
      ├── web
      │   └── nginx
      ├── 42
      └── sym
          └── 1.5
    TREE
  end

  def test_a_root_with_no_children
    assert_equal "app@1.0\n", printed { CLI.tree("app@1.0") }
    assert_equal "app@1.0\n", printed { CLI.tree("app@1.0", {}) }
  end

  def test_without_a_root_the_children_are_a_forest
    out = printed { CLI.tree({ "a" => ["a1"], "b" => nil }) }
    assert_equal <<~TREE, out
      ├── a
      │   └── a1
      └── b
    TREE
  end

  def test_multi_line_labels_keep_the_rail
    out = printed { CLI.tree("app", ["first\nsecond", "last"]) }
    assert_equal <<~TREE, out
      app
      ├── first
      │   second
      └── last
    TREE
  end

  def test_returns_nil_and_writes_only_stdout
    value, shell = with_shell { CLI.tree("app", ["a"]) }
    assert_nil value
    assert_equal "", shell.error.string
    refute_includes shell.output.string, "\e"
  end

  # ---- depth ----

  def test_depth_truncates_with_an_ellipsis
    out = printed { CLI.tree("app@1.0", DEPS, depth: 1) }
    assert_equal <<~TREE, out
      app@1.0
      ├── rails@7.1
      │   └── …
      └── pg@1.5
    TREE
  end

  def test_depth_two_and_a_depth_past_the_bottom
    out = printed { CLI.tree("app@1.0", DEPS, depth: 2) }
    assert_equal <<~TREE, out
      app@1.0
      ├── rails@7.1
      │   ├── rack@3.0
      │   └── activesupport@7.1
      │       └── …
      └── pg@1.5
    TREE
    assert_equal printed { CLI.tree("app@1.0", DEPS) }, printed { CLI.tree("app@1.0", DEPS, depth: 9) }
  end

  def test_depth_zero_shows_only_the_root
    assert_equal "app@1.0\n└── …\n", printed { CLI.tree("app@1.0", DEPS, depth: 0) }
    assert_equal "app@1.0\n", printed { CLI.tree("app@1.0", {}, depth: 0) }
  end

  def test_bad_depth_raises
    with_shell do
      assert_raises(ArgumentError) { CLI.tree("app", DEPS, depth: -1) }
      assert_raises(ArgumentError) { CLI.tree("app", DEPS, depth: "1") }
    end
  end

  # ---- on a terminal ----

  def test_terminal_styles_the_root_and_names_with_the_same_glyphs
    plain = printed { CLI.tree("app@1.0", DEPS) }
    styled = with_ansi { printed(tty: true, color: true) { CLI.tree("app@1.0", DEPS) } }
    assert_match ESC, styled
    assert_equal plain, styled.gsub(ESC, "")
    first = styled.lines.first
    assert_match(/\e\[[\d;]*\b1[;m]/, first, "root is bold")
    refute_includes first, "├", "the root line has no connector"
    rails = styled.lines[1]
    assert_match(/\e\[[\d;]*m[├└]──/, rails, "connectors are styled")
    assert_match(/\e\[[\d;]*mrails/, rails, "names are styled")
  end

  def test_no_colour_on_a_terminal_prints_the_plain_tree
    plain = printed { CLI.tree("app@1.0", DEPS) }
    out = with_ansi { printed(tty: true, color: false) { CLI.tree("app@1.0", DEPS) } }
    assert_equal plain, out
  end

  def test_scoped_package_names_keep_their_at_sign
    styled = with_ansi { printed(tty: true, color: true) { CLI.tree("app", ["@types/node@20.1", "plain"]) } }
    assert_equal "app\n├── @types/node@20.1\n└── plain\n", styled.gsub(ESC, "")
  end

  # ---- in a command ----

  def test_in_a_command
    tool = CLI::Program.build("tool") do
      argument :app
      run { tree(args[:app], { "rails@7.1" => nil }) }
    end
    result = run_cli(tool, "api")
    assert_equal 0, result.code
    assert_equal "api\n└── rails@7.1\n", result.out
    assert_equal "", result.err
  end
end
