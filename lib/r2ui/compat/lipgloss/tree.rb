# frozen_string_literal: true

require_relative "tree/go_tree"

module Lipgloss
  # Lipgloss::Tree as the gem's C extension (tree.c) defines it over Go lipgloss tree.Tree. Every method
  # mutates the underlying tree and returns a new Lipgloss::Tree wrapping that same tree.
  class Tree
    def self.root(root)
      value = R2UI::Compat::Gloss::GoTree.c_string_arg(root)
      tree = allocate
      tree.instance_variable_set(:@tree, R2UI::Compat::Gloss::GoTree::Node.new.root(value))
      tree
    end

    def initialize(*args)
      node = go_tree
      node.root(R2UI::Compat::Gloss::GoTree.c_string_arg(args[0])) if args.length == 1
    end

    def root=(root)
      node = go_tree
      node.root(R2UI::Compat::Gloss::GoTree.c_string_arg(root))
      wrap(node)
    end

    def child(*children)
      node = go_tree
      raise ArgumentError, "wrong number of arguments (given 0, expected 1+)" if children.empty?

      children.each do |child|
        if child.is_a?(Lipgloss::Tree)
          node.child(child.send(:go_tree))
        else
          node.child(R2UI::Compat::Gloss::GoTree.c_string_arg(child))
        end
      end
      wrap(node)
    end

    def children(children)
      node = go_tree
      strs = R2UI::Compat::Gloss::GoTree.json_string_array(children)
      strs&.each { |s| node.child(s) }
      wrap(node)
    end

    def enumerator(enum_symbol)
      node = go_tree
      node.ensure_renderer.enumerator =
        if enum_symbol.equal?(:rounded)
          R2UI::Compat::Gloss::GoTree::ROUNDED_ENUMERATOR
        else
          R2UI::Compat::Gloss::GoTree::DEFAULT_ENUMERATOR
        end
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

    def root_style(style)
      node = go_tree
      node.ensure_renderer.root_style = R2UI::Compat::Gloss::GoTree.style_arg(style)
      wrap(node)
    end

    def offset(start, stop)
      node = go_tree
      layout = R2UI::Compat::Gloss::Layout
      node.set_offset(layout.num2int(start), layout.num2int(stop))
      wrap(node)
    end

    def render
      R2UI::Compat::Gloss::GoTree.render(go_tree)
    end

    def to_s
      render
    end

    private

    # The gem allocates the Go tree in the alloc function, so even an uninitialized object has one.
    def go_tree
      @tree ||= R2UI::Compat::Gloss::GoTree::Node.new
    end

    def wrap(node)
      tree = self.class.allocate
      tree.instance_variable_set(:@tree, node)
      tree
    end
  end
end
