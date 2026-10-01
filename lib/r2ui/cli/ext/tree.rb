# frozen_string_literal: true

# c08-tree: a dependency-style tree (npm ls, cargo tree, tree(1)), drawn by Lipgloss::Tree.
#
#   tree("app@1.0", { "rails@7.1" => { "rack@3.0" => nil }, "pg@1.5" => nil })
#
#   app@1.0
#   ├── rails@7.1
#   │   └── rack@3.0
#   └── pg@1.5
#
# Children nest as Hashes (label => children; nil for a leaf, a single value for one child) and
# Arrays (leaves as Strings, Hashes for branches). An Array right after an item in an Array nests
# under that item, the way Lipgloss::Tree treats a rootless subtree:
#
#   tree("src", ["main.rb", { "lib" => %w[a.rb b.rb] }, "README.md"])
#   tree("root", ["a", %w[a1 a2], "b"])                  # a1 and a2 hang under "a"
#   tree({ "a" => nil, "b" => nil })                     # no root line: just the branches
#
# Labels are anything with #to_s; multi-line labels keep the rail on their later lines.
# `depth: n` shows n levels below the root and puts one "…" under each branch it cuts
# (`depth: 0` is the root and "└── …").
#
# On a terminal the root is bold, names are in the accent colour with "@version" muted, and the
# connectors are muted. Off a terminal (pipe, CI, NO_COLOR) it prints the same lines with the same
# glyphs and no escape codes, so `tool deps | grep rack` works. Printed through the Shell, so
# inside a Live region (tasks, spinners) it lands above the region. Returns nil.
module R2UI
  module CLI
    module Ext
      module DepTree
        ELLIPSIS = "…"
        # "name@version": the last "@" that isn't the first character ("@types/node@20.1").
        VERSIONED = /\A(?<name>.+?)(?<version>@[^@\/\s]+)\z/

        Node = Struct.new(:label, :children)

        module_function

        # Children in any accepted shape → [Node].
        def nodes(value)
          case value
          when nil then []
          when Hash then value.map { |label, kids| Node.new(label.to_s, nodes(kids)) }
          when Array then array_nodes(value)
          else [Node.new(value.to_s, [])]
          end
        end

        def array_nodes(items)
          items.each_with_object([]) do |item, list|
            if item.is_a?(Array) && !list.empty?
              list.last.children.concat(nodes(item))
            else
              list.concat(nodes(item))
            end
          end
        end

        # Cuts the branches below `depth` levels, leaving one "…" in their place.
        def truncate(list, depth)
          return list if depth.nil?
          return list.empty? ? [] : [Node.new(ELLIPSIS, [])] if depth.zero?

          list.map { |node| Node.new(node.label, truncate(node.children, depth - 1)) }
        end

        def render(shell, root, list)
          tree = Lipgloss::Tree.root(root.nil? ? "" : label(shell, root.to_s, root: true))
          tree = tree.enumerator_style(shell.theme.style(:muted).padding_right(1)) if shell.color?
          list.each { |node| tree = tree.child(build(shell, node)) }
          # Lipgloss pads a multi-line item to a block; drop that padding so piped lines stay clean.
          tree.render.split("\n").map(&:rstrip).join("\n")
        end

        def build(shell, node)
          text = label(shell, node.label)
          return text if node.children.empty?

          node.children.reduce(Lipgloss::Tree.root(text)) { |tree, child| tree.child(build(shell, child)) }
        end

        def label(shell, text, root: false)
          return shell.paint(text, :muted) if text == ELLIPSIS

          name_style = root ? :heading : :accent
          match = text.include?("\n") ? nil : VERSIONED.match(text)
          return shell.paint(text, name_style) unless match

          shell.paint(match[:name], name_style) + shell.paint(match[:version], :muted)
        end
      end
    end

    extension :tree do
      helpers do
        def tree(root, children = nil, depth: nil)
          unless depth.nil? || (depth.is_a?(Integer) && !depth.negative?)
            raise ArgumentError, "depth must be a non-negative Integer, got #{depth.inspect}"
          end

          if children.nil? && (root.is_a?(Hash) || root.is_a?(Array))
            children = root
            root = nil
          end
          list = Ext::DepTree.truncate(Ext::DepTree.nodes(children), depth)
          text = Ext::DepTree.render(shell, root, list)
          shell.puts(text) unless text.empty?
          nil
        end
      end
    end
  end
end
