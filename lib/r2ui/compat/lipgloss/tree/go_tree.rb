# frozen_string_literal: true

# A port of lipgloss v1.1.0 tree/ (tree.go, children.go, enumerator.go, renderer.go) and the
# enumerators of list/ (list/enumerator.go). Lipgloss::Tree and Lipgloss::List wrap a GoTree::Node,
# the way the gem's Ruby objects wrap a handle to a Go *tree.Tree / *list.List: every method mutates
# that shared node, and the returned Ruby object is a fresh wrapper around the same node.
#
# Only what the gem's Ruby API can reach is ported: no hidden nodes, no style or enumerator funcs
# that look at the children (the Ruby API only sets constant styles and the built-in enumerators).
module R2UI
  module Compat
    module Gloss
      module GoTree
        UTF_8 = Encoding::UTF_8

        # tree.Leaf
        class Leaf
          attr_accessor :value

          def initialize(value)
            @value = value
          end
        end

        # tree.Tree
        class Node
          attr_accessor :value, :children, :offset, :r

          def initialize
            @value = +""
            @children = []
            @offset = [0, 0]
            @r = nil
          end

          # Tree.Root(string)
          def root(value)
            @value = value
            self
          end

          # Tree.Children(): the children inside the offset window.
          def visible_children
            (@offset[0]...(@children.length - @offset[1])).map { |i| @children[i] }
          end

          # Tree.Child for one *Tree, Node or string.
          def child(item)
            case item
            when Node
              new_item, rm = ensure_parent(@children, item)
              @children.delete_at(rm) if rm >= 0
              @children << new_item
            when Leaf
              @children << item
            when String
              @children << Leaf.new(item)
            end
            self
          end

          # Tree.Offset
          def set_offset(start, stop)
            start, stop = stop, start if start > stop
            start = 0 if start.negative?
            stop = @children.length if stop.negative? || stop > @children.length
            @offset = [start, stop]
            self
          end

          def ensure_renderer
            @r ||= Renderer.new
          end

          # Tree.String()
          def to_s
            ensure_renderer.render(self, true, "")
          end

          private

          # tree.go ensureParent: a tree without a root takes over the previous leaf's value (or merges
          # into the previous subtree).
          def ensure_parent(nodes, item)
            return [item, -1] if item.value != "" || nodes.empty?

            j = nodes.length - 1
            parent = nodes[j]
            case parent
            when Node
              i = 0
              while i < item.visible_children.length
                parent.child(item.children[i])
                i += 1
              end
              [parent, j]
            else
              item.value = parent.value
              [item, j]
            end
          end
        end

        DEFAULT_ENUMERATOR = ->(children, index) { children.length - 1 == index ? "└──" : "├──" }
        ROUNDED_ENUMERATOR = ->(children, index) { children.length - 1 == index ? "╰──" : "├──" }
        DEFAULT_INDENTER = ->(children, index) { children.length - 1 == index ? "   " : "│  " }

        # list/enumerator.go
        module ListEnumerators
          ABC_LEN = 26
          ROMAN = %w[M CM D CD C XC L XL X IX V IV I].freeze
          ARABIC = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1].freeze

          BULLET = ->(_items, _i) { "•" }
          ASTERISK = ->(_items, _i) { "*" }
          DASH = ->(_items, _i) { "-" }
          ARABIC_ENUM = ->(_items, i) { "#{i + 1}." }

          ALPHABET = lambda do |_items, i|
            a = "A".ord
            if i >= ABC_LEN * ABC_LEN + ABC_LEN
              [a + i / ABC_LEN / ABC_LEN - 1, a + (i / ABC_LEN) % ABC_LEN - 1, a + i % ABC_LEN].pack("U*") + "."
            elsif i >= ABC_LEN
              [a + i / ABC_LEN - 1, a + i % ABC_LEN].pack("U*") + "."
            else
              [a + i % ABC_LEN].pack("U*") + "."
            end
          end

          ROMAN_ENUM = lambda do |_items, i|
            result = +""
            ARABIC.each_with_index do |value, v|
              while i >= value - 1
                i -= value
                result << ROMAN[v]
              end
            end
            result << "."
          end

          INDENTER = ->(_items, _i) { " " }
        end

        # list.New(): a tree with the bullet enumerator and a one-space indenter.
        def self.new_list
          node = Node.new
          r = node.ensure_renderer
          r.enumerator = ListEnumerators::BULLET
          r.indenter = ListEnumerators::INDENTER
          node
        end

        # tree/renderer.go
        class Renderer
          attr_accessor :enumerator_style, :item_style, :root_style, :enumerator, :indenter

          def initialize
            @enumerator_style = ::Lipgloss::Style.new.padding_right(1)
            @item_style = ::Lipgloss::Style.new
            @root_style = ::Lipgloss::Style.new
            @enumerator = DEFAULT_ENUMERATOR
            @indenter = DEFAULT_INDENTER
          end

          def render(node, root, prefix)
            strs = []
            max_len = 0
            children = node.is_a?(Node) ? node.visible_children : []

            name = node.value
            strs << style_render(@root_style, name) if name != "" && root

            children.each_index do |i|
              p = style_render(@enumerator_style, @enumerator.call(children, i))
              w = layout.width(p)
              max_len = w if w > max_len
            end

            children.each_with_index do |child, i|
              indent = @indenter.call(children, i)
              node_prefix = style_render(@enumerator_style, @enumerator.call(children, i))
              l = max_len - layout.width(node_prefix)
              node_prefix = (" " * l) + node_prefix if l.positive?

              item = style_render(@item_style, child.value)
              multiline_prefix = prefix

              while layout.height(item) > layout.height(node_prefix)
                node_prefix = layout.join_vertical(0.0, [node_prefix, style_render(@enumerator_style, indent)])
              end
              while layout.height(node_prefix) > layout.height(multiline_prefix)
                multiline_prefix = layout.join_vertical(0.0, [multiline_prefix, prefix])
              end

              strs << layout.join_horizontal(0.0, [multiline_prefix, node_prefix, item])

              renderer = (child.is_a?(Node) && child.r) || self
              s = renderer.render(child, false, prefix + style_render(@enumerator_style, indent))
              strs << s unless s.empty?
            end
            strs.join("\n")
          end

          private

          def layout = Layout

          def style_render(style, str)
            style.send(:go_render, str)
          end
        end

        # --- Ruby-side argument handling shared by Lipgloss::List and Lipgloss::Tree --------------

        # Check_Type(value, T_STRING) + StringValueCStr, copied the way Go copies a C string.
        def self.c_string_arg(value)
          Layout.check_string(value)
          String.new(Layout.c_string(value), encoding: UTF_8)
        end

        # Array#to_json unmarshalled into []string (nil when the unmarshal fails).
        def self.json_string_array(array)
          Layout.check_array(array)
          strs = Layout.json_strings(array)
          return nil if strs.equal?(Layout::JSON_FAIL)

          strs.map { |s| String.new(s, encoding: UTF_8) }
        end

        # TypedData_Get_Struct(style, ..., &style_type)
        def self.style_arg(style)
          return style if style.is_a?(::Lipgloss::Style)

          raise TypeError, "wrong argument type #{Layout.type_name(style)} (expected Lipgloss::Style)"
        end

        def self.render(node)
          Layout.c_result(node.to_s)
        end
      end
    end
  end
end
