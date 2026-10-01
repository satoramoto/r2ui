# frozen_string_literal: true

require_relative "tree/go_tree"

module Lipgloss
  # Lipgloss::List as the gem's C extension (list.c) defines it over Go lipgloss list.List (a tree.Tree
  # with list enumerators). Every method mutates the underlying list and returns a new Lipgloss::List
  # wrapping that same list.
  class List
    ENUMERATORS = {
      bullet: R2UI::Compat::Gloss::GoTree::ListEnumerators::BULLET,
      arabic: R2UI::Compat::Gloss::GoTree::ListEnumerators::ARABIC_ENUM,
      alphabet: R2UI::Compat::Gloss::GoTree::ListEnumerators::ALPHABET,
      roman: R2UI::Compat::Gloss::GoTree::ListEnumerators::ROMAN_ENUM,
      dash: R2UI::Compat::Gloss::GoTree::ListEnumerators::DASH,
      asterisk: R2UI::Compat::Gloss::GoTree::ListEnumerators::ASTERISK
    }.freeze
    private_constant :ENUMERATORS

    def initialize(*items)
      node = go_tree
      return if items.empty?

      strs = R2UI::Compat::Gloss::GoTree.json_string_array(items)
      strs&.each { |s| node.child(s) }
    end

    def item(item)
      node = go_tree
      if item.is_a?(Lipgloss::List)
        node.child(item.send(:go_tree))
      else
        node.child(R2UI::Compat::Gloss::GoTree.c_string_arg(item))
      end
      wrap(node)
    end

    def items(items)
      node = go_tree
      strs = R2UI::Compat::Gloss::GoTree.json_string_array(items)
      strs&.each { |s| node.child(s) }
      wrap(node)
    end

    def enumerator(enum_symbol)
      node = go_tree
      enum = ENUMERATORS.find { |sym, _| sym.equal?(enum_symbol) }&.last
      node.ensure_renderer.enumerator = enum || ENUMERATORS[:bullet]
      wrap(node)
    end

    def enumerator_style(style)
      node = go_tree
      node.ensure_renderer.enumerator_style = R2UI::Compat::Gloss::GoTree.style_arg(style)
      wrap(node)
    end

    def item_style(style)
      node = go_tree
      node.ensure_renderer.item_style = R2UI::Compat::Gloss::GoTree.style_arg(style)
      wrap(node)
    end

    def render
      R2UI::Compat::Gloss::GoTree.render(go_tree)
    end

    def to_s
      render
    end

    private

    # The gem allocates the Go list (list.New()) in the alloc function.
    def go_tree
      @tree ||= R2UI::Compat::Gloss::GoTree.new_list
    end

    def wrap(node)
      list = self.class.allocate
      list.instance_variable_set(:@tree, node)
      list
    end
  end
end
