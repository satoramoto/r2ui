# frozen_string_literal: true

require_relative "table/render"

# Lipgloss::Table: the lipgloss gem 0.2.2 table (ext/lipgloss/table.c, go/table.go, lib/lipgloss/table.rb;
# MIT, Marco Roth) over a port of Go lipgloss v1.1.0 table/ (table.go, resizing.go, rows.go, util.go).
#
# The gem's Go table is a pointer: every setter mutates it in place and the C extension wraps the same
# table in a fresh Ruby object of the receiver's class. So `t.row([...])` changes `t`, and the returned
# object shares that state. Arrays cross into Go as JSON unmarshalled into []string: a non-String element
# (other than nil, a Symbol or a plain object) fails the unmarshal and the call changes nothing.
module Lipgloss
  class Table
    Gloss = R2UI::Compat::Gloss
    private_constant :Gloss

    BORDER_NAMES = %i[normal rounded thick double hidden block outer_half_block inner_half_block ascii
                      markdown].freeze
    private_constant :BORDER_NAMES

    def initialize
      @t = Gloss::TableRender::State.new
    end

    def headers(headers)
      Gloss::Layout.check_array(headers)
      strs = Gloss::Layout.json_strings(headers)
      @t.headers = strs unless strs.equal?(Gloss::Layout::JSON_FAIL)
      _rewrap
    end

    def row(row)
      Gloss::Layout.check_array(row)
      strs = Gloss::Layout.json_strings(row)
      @t.append(strs) unless strs.equal?(Gloss::Layout::JSON_FAIL)
      _rewrap
    end

    def rows(rows)
      Gloss::Layout.check_array(rows)
      parsed = Gloss::TableRender.json_rows(rows)
      parsed&.each { |r| @t.append(r) }
      _rewrap
    end

    def border(border_sym)
      name = BORDER_NAMES.find { |n| n.equal?(border_sym) } || :normal
      @t.border = Gloss::Borders.fetch(name)
      _rewrap
    end

    def border_style(style_object)
      Gloss::TableRender.check_style(style_object)
      @t.border_style = style_object
      _rewrap
    end

    def border_top(value)
      @t.border_top = value ? true : false
      _rewrap
    end

    def border_bottom(value)
      @t.border_bottom = value ? true : false
      _rewrap
    end

    def border_left(value)
      @t.border_left = value ? true : false
      _rewrap
    end

    def border_right(value)
      @t.border_right = value ? true : false
      _rewrap
    end

    def border_header(value)
      @t.border_header = value ? true : false
      _rewrap
    end

    def border_column(value)
      @t.border_column = value ? true : false
      _rewrap
    end

    def border_row(value)
      @t.border_row = value ? true : false
      _rewrap
    end

    def width(width)
      @t.width = Gloss::Layout.num2int(width)
      _rewrap
    end

    def height(height)
      @t.height = Gloss::Layout.num2int(height)
      @t.use_manual_height = true
      _rewrap
    end

    def offset(offset)
      @t.offset = Gloss::Layout.num2int(offset)
      _rewrap
    end

    def wrap(value)
      @t.wrap = value ? true : false
      _rewrap
    end

    def clear_rows
      @t.clear_rows
      _rewrap
    end

    # Apply a pre-computed style map: { "row,col" => style, ... }
    def _style_func_map(style_map)
      unless style_map.is_a?(Hash)
        raise TypeError, "wrong argument type #{Gloss::Layout.type_name(style_map)} (expected Hash)"
      end

      map = {}
      style_map.each_key do |key|
        style = style_map[key]
        Gloss::TableRender.check_style(style)
        map[key.to_s] = style
      end
      @t.style_map = map
      _rewrap
    end

    def render
      Gloss::Layout.c_result(Gloss::TableRender.new(@t).render)
    end

    def to_s
      render
    end

    private

    # table_wrap(rb_class_of(self), handle): a new Ruby object over the same table.
    def _rewrap
      obj = self.class.allocate
      obj.instance_variable_set(:@t, @t)
      obj
    end
  end
end

# Ruby-level conveniences, as in the gem's lib/lipgloss/table.rb (MIT, Marco Roth).
module Lipgloss
  class Table
    # Header row constant (used in style_func)
    HEADER_ROW = -1

    # Set a style function that determines the style for each cell
    def style_func(rows:, columns:, &block)
      raise ArgumentError, "block required" unless block_given?
      raise ArgumentError, "rows must be >= 0" if rows.negative?
      raise ArgumentError, "columns must be > 0" if columns <= 0

      style_map = {} #: Hash[String, Style]

      # Header row
      columns.times do |column|
        style = block.call(HEADER_ROW, column)
        style_map["#{HEADER_ROW},#{column}"] = style if style
      end

      # Data rows
      rows.times do |row|
        columns.times do |column|
          style = block.call(row, column)
          style_map["#{row},#{column}"] = style if style
        end
      end

      _style_func_map(style_map)
    end
  end
end
