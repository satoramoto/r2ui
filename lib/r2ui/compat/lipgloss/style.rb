# frozen_string_literal: true

# Lipgloss::Style: a port of lipgloss v1.1.0 style.go, set.go, get.go, unset.go, borders.go and
# align.go, behind the same Ruby-facing argument handling as the lipgloss gem 0.2.2 C extension
# (ext/lipgloss/style*.c, go/style*.go) and its lib/lipgloss/style.rb (align wrappers).
#
# Styles are immutable: every setter returns a new Style, like the gem (which allocates a new Go
# style per call). Like the gem, #dup and #clone give an empty style (the C extension allocates a
# fresh Go style and copies nothing).
#
# Private API for the table / list / tree ports (call with #send):
#   get_padding / get_margin -> [top, right, bottom, left]
#   get_horizontal_padding, get_vertical_padding, get_horizontal_margins, get_vertical_margins,
#   get_horizontal_frame_size, get_vertical_frame_size, get_horizontal_border_size,
#   get_vertical_border_size, get_border_style -> BorderDef, get_align_horizontal -> Float,
#   get_align_vertical -> Float, get_max_width, get_max_height, get_inline,
#   get_border_top_size / _right_size / _bottom_size / _left_size, get_border -> [def, t, r, b, l]
#   set_border_def(border_def, *sides)   Go Border(b, sides...)
#   set_border_style_def(border_def)     Go BorderStyle(b)
#   set_foreground_color(terminal_color) / set_background_color(terminal_color)
#   go_render(*strs)                     Go Render(strs...), no Ruby argument checks
require_relative "style/border"

module R2UI
  module Compat
    module Gloss
      # The gem's Style is a T_DATA object with no instance variables, so it inspects as
      # #<Lipgloss::Style:0x...>. Kept in a module so Style.public_instance_methods(false) stays
      # exactly the gem's list.
      module StyleInspect
        def inspect = Object.instance_method(:to_s).bind_call(self)

        def pretty_print(q)
          q.text(inspect)
        end
      end
    end
  end
end

module Lipgloss
  class Style
    include R2UI::Compat::Gloss::StyleInspect
    # propKey values (style.go), in Go's order.
    module Keys
      names = %i[
        bold italic underline strikethrough reverse blink faint underline_spaces strikethrough_spaces
        color_whitespace
        foreground background width height align_horizontal align_vertical
        padding_top padding_right padding_bottom padding_left
        margin_top margin_right margin_bottom margin_left margin_background
        border_style
        border_top border_right border_bottom border_left
        border_top_foreground border_right_foreground border_bottom_foreground border_left_foreground
        border_top_background border_right_background border_bottom_background border_left_background
        inline max_width max_height tab_width
        transform
      ]
      names.each_with_index { |name, i| const_set(name.to_s.upcase, 1 << i) }
      FIRST = BOLD
      LAST = TRANSFORM

      COLOR = [
        FOREGROUND, BACKGROUND, MARGIN_BACKGROUND,
        BORDER_TOP_FOREGROUND, BORDER_RIGHT_FOREGROUND, BORDER_BOTTOM_FOREGROUND, BORDER_LEFT_FOREGROUND,
        BORDER_TOP_BACKGROUND, BORDER_RIGHT_BACKGROUND, BORDER_BOTTOM_BACKGROUND, BORDER_LEFT_BACKGROUND
      ].freeze
      NON_NEGATIVE = [
        WIDTH, HEIGHT, PADDING_TOP, PADDING_RIGHT, PADDING_BOTTOM, PADDING_LEFT,
        MARGIN_TOP, MARGIN_RIGHT, MARGIN_BOTTOM, MARGIN_LEFT, MAX_WIDTH, MAX_HEIGHT
      ].freeze
      VALUE = [ALIGN_HORIZONTAL, ALIGN_VERTICAL, BORDER_STYLE, TAB_WIDTH, TRANSFORM].freeze
      STORED = (COLOR + NON_NEGATIVE + VALUE).to_h { |k| [k, true] }.freeze
      NON_NEGATIVE_SET = NON_NEGATIVE.to_h { |k| [k, true] }.freeze
    end
    private_constant :Keys

    Gloss = R2UI::Compat::Gloss
    private_constant :Gloss

    UTF_8 = Encoding::UTF_8
    private_constant :UTF_8

    TAB_WIDTH_DEFAULT = 4
    private_constant :TAB_WIDTH_DEFAULT

    def initialize
      reset_state
    end

    def render(string)
      Gloss::Layout.check_string(string)
      c_result(go_render(c_str(string)))
    end

    # --- text attributes -------------------------------------------------------------------------

    def bold(value) = with(Keys::BOLD, value ? true : false)
    def italic(value) = with(Keys::ITALIC, value ? true : false)
    def underline(value) = with(Keys::UNDERLINE, value ? true : false)
    def strikethrough(value) = with(Keys::STRIKETHROUGH, value ? true : false)
    def reverse(value) = with(Keys::REVERSE, value ? true : false)
    def blink(value) = with(Keys::BLINK, value ? true : false)
    def faint(value) = with(Keys::FAINT, value ? true : false)

    # --- colors ----------------------------------------------------------------------------------

    def foreground(color)
      with(Keys::FOREGROUND, Gloss::Renderer.terminal_color(color))
    end

    def background(color)
      with(Keys::BACKGROUND, Gloss::Renderer.terminal_color(color))
    end

    def margin_background(color)
      with(Keys::MARGIN_BACKGROUND, Gloss::Renderer.terminal_color(color, adaptive: false, complete: false))
    end

    # --- size ------------------------------------------------------------------------------------

    def width(width) = with(Keys::WIDTH, num2int(width))
    def height(height) = with(Keys::HEIGHT, num2int(height))
    def max_width(width) = with(Keys::MAX_WIDTH, num2int(width))
    def max_height(height) = with(Keys::MAX_HEIGHT, num2int(height))

    # --- alignment (lib/lipgloss/style.rb + style.c) ---------------------------------------------

    def align(*positions)
      _align(*positions.map { |p| Position.resolve(p) })
    end

    def align_horizontal(position)
      _align_horizontal(Position.resolve(position))
    end

    def align_vertical(position)
      _align_vertical(Position.resolve(position))
    end

    def _align(*positions)
      if positions.empty? || positions.length > 2
        raise ArgumentError, "wrong number of arguments (given #{positions.length}, expected 1..2)"
      end

      values = positions.map { |p| Gloss::Layout.num2dbl(p) }
      derive do |s|
        s.__send__(:set!, Keys::ALIGN_HORIZONTAL, values[0])
        s.__send__(:set!, Keys::ALIGN_VERTICAL, values[1]) if values.length > 1
      end
    end

    def _align_horizontal(position)
      with(Keys::ALIGN_HORIZONTAL, Gloss::Layout.num2dbl(position))
    end

    def _align_vertical(position)
      with(Keys::ALIGN_VERTICAL, Gloss::Layout.num2dbl(position))
    end

    # --- other -----------------------------------------------------------------------------------

    def inline(value) = with(Keys::INLINE, value ? true : false)

    def tab_width(width)
      n = num2int(width)
      n = -1 if n <= -1
      with(Keys::TAB_WIDTH, n)
    end

    def underline_spaces(value) = with(Keys::UNDERLINE_SPACES, value ? true : false)
    def strikethrough_spaces(value) = with(Keys::STRIKETHROUGH_SPACES, value ? true : false)

    def set_string(string)
      Gloss::Layout.check_string(string)
      str = c_str(string)
      derive { |s| s.instance_variable_set(:@value, str) }
    end

    def inherit(other)
      unless other.is_a?(Style)
        raise TypeError, "wrong argument type #{Gloss::Layout.type_name(other)} (expected Lipgloss::Style)"
      end

      derive { |s| s.__send__(:inherit!, other) }
    end

    def to_s
      c_result(go_render)
    end

    # --- getters ---------------------------------------------------------------------------------

    def bold? = get_as_bool(Keys::BOLD, false)
    def italic? = get_as_bool(Keys::ITALIC, false)
    def underline? = get_as_bool(Keys::UNDERLINE, false)
    def strikethrough? = get_as_bool(Keys::STRIKETHROUGH, false)
    def reverse? = get_as_bool(Keys::REVERSE, false)
    def blink? = get_as_bool(Keys::BLINK, false)
    def faint? = get_as_bool(Keys::FAINT, false)

    def get_foreground = color_string(get_as_color(Keys::FOREGROUND))
    def get_background = color_string(get_as_color(Keys::BACKGROUND))
    def get_width = get_as_int(Keys::WIDTH)
    def get_height = get_as_int(Keys::HEIGHT)

    # --- padding / margin (style_spacing.c) ------------------------------------------------------

    def padding(*values)
      sides = spacing_args(values)
      derive { |s| s.__send__(:set_sides!, :padding, sides) }
    end

    def padding_top(value) = with(Keys::PADDING_TOP, num2int(value))
    def padding_right(value) = with(Keys::PADDING_RIGHT, num2int(value))
    def padding_bottom(value) = with(Keys::PADDING_BOTTOM, num2int(value))
    def padding_left(value) = with(Keys::PADDING_LEFT, num2int(value))

    def margin(*values)
      sides = spacing_args(values)
      derive { |s| s.__send__(:set_sides!, :margin, sides) }
    end

    def margin_top(value) = with(Keys::MARGIN_TOP, num2int(value))
    def margin_right(value) = with(Keys::MARGIN_RIGHT, num2int(value))
    def margin_bottom(value) = with(Keys::MARGIN_BOTTOM, num2int(value))
    def margin_left(value) = with(Keys::MARGIN_LEFT, num2int(value))

    # --- borders (style_border.c) ----------------------------------------------------------------

    def border(*args)
      raise ArgumentError, "wrong number of arguments (given 0, expected 1+)" if args.empty?

      border = Gloss::Borders.resolve(args[0])
      sides = args[1, 4].map { |v| v ? true : false }
      set_border_def(border, *sides)
    end

    def border_style(type)
      set_border_style_def(Gloss::Borders.resolve(type))
    end

    def border_foreground(color)
      c = Gloss::Renderer.terminal_color(color, complete: false)
      derive { |s| s.__send__(:set_border_colors!, :foreground, [c]) }
    end

    def border_background(color)
      c = Gloss::Renderer.terminal_color(color, complete: false)
      derive { |s| s.__send__(:set_border_colors!, :background, [c]) }
    end

    def border_top(value) = with(Keys::BORDER_TOP, value ? true : false)
    def border_right(value) = with(Keys::BORDER_RIGHT, value ? true : false)
    def border_bottom(value) = with(Keys::BORDER_BOTTOM, value ? true : false)
    def border_left(value) = with(Keys::BORDER_LEFT, value ? true : false)

    def border_top_foreground(color) = with(Keys::BORDER_TOP_FOREGROUND, side_color(color))
    def border_right_foreground(color) = with(Keys::BORDER_RIGHT_FOREGROUND, side_color(color))
    def border_bottom_foreground(color) = with(Keys::BORDER_BOTTOM_FOREGROUND, side_color(color))
    def border_left_foreground(color) = with(Keys::BORDER_LEFT_FOREGROUND, side_color(color))
    def border_top_background(color) = with(Keys::BORDER_TOP_BACKGROUND, side_color(color))
    def border_right_background(color) = with(Keys::BORDER_RIGHT_BACKGROUND, side_color(color))
    def border_bottom_background(color) = with(Keys::BORDER_BOTTOM_BACKGROUND, side_color(color))
    def border_left_background(color) = with(Keys::BORDER_LEFT_BACKGROUND, side_color(color))

    BORDER_CUSTOM_KEYS = %i[
      top bottom left right top_left top_right bottom_left bottom_right
      middle_left middle_right middle middle_top middle_bottom
    ].freeze
    private_constant :BORDER_CUSTOM_KEYS

    def border_custom(*args, **opts)
      raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 0)" unless args.empty?
      raise ArgumentError, "keyword arguments required" if opts.empty?

      fields = BORDER_CUSTOM_KEYS.map do |k|
        v = opts[k]
        v.nil? ? "" : c_str(v)
      end
      set_border_def(Gloss::BorderDef.new(*fields))
    end

    # --- unset (style_unset.c) -------------------------------------------------------------------

    def unset_bold = without(Keys::BOLD)
    def unset_italic = without(Keys::ITALIC)
    def unset_underline = without(Keys::UNDERLINE)
    def unset_strikethrough = without(Keys::STRIKETHROUGH)
    def unset_reverse = without(Keys::REVERSE)
    def unset_blink = without(Keys::BLINK)
    def unset_faint = without(Keys::FAINT)
    def unset_foreground = without(Keys::FOREGROUND)
    def unset_background = without(Keys::BACKGROUND)
    def unset_width = without(Keys::WIDTH)
    def unset_height = without(Keys::HEIGHT)
    def unset_padding_top = without(Keys::PADDING_TOP)
    def unset_padding_right = without(Keys::PADDING_RIGHT)
    def unset_padding_bottom = without(Keys::PADDING_BOTTOM)
    def unset_padding_left = without(Keys::PADDING_LEFT)
    def unset_margin_top = without(Keys::MARGIN_TOP)
    def unset_margin_right = without(Keys::MARGIN_RIGHT)
    def unset_margin_bottom = without(Keys::MARGIN_BOTTOM)
    def unset_margin_left = without(Keys::MARGIN_LEFT)
    def unset_border_style = without(Keys::BORDER_STYLE)
    def unset_inline = without(Keys::INLINE)

    private

    # --- state -----------------------------------------------------------------------------------

    def reset_state
      @props = 0
      @attrs = 0
      @values = {}
      @value = ""
    end

    # The gem's dup/clone allocate a fresh, empty Go style.
    def initialize_copy(_other)
      super
      reset_state
    end

    def load_state(props, attrs, values, value)
      @props = props
      @attrs = attrs
      @values = values
      @value = value
    end

    def derive
      s = self.class.allocate
      s.__send__(:load_state, @props, @attrs, @values.dup, @value)
      yield s
      s
    end

    def with(key, value)
      derive { |s| s.__send__(:set!, key, value) }
    end

    def without(key)
      derive { |s| s.__send__(:unset!, key) }
    end

    # Style.set (set.go)
    def set!(key, value)
      if Keys::STORED.key?(key)
        value = [0, value].max if Keys::NON_NEGATIVE_SET.key?(key)
        @values[key] = value
      elsif value == true || value == false
        value ? (@attrs |= key) : (@attrs &= ~key)
      elsif value.is_a?(Integer)
        (value & key).zero? ? (@attrs &= ~key) : (@attrs |= key)
      end
      @props |= key
    end

    def unset!(key)
      @props &= ~key
    end

    def set?(key) = (@props & key) != 0

    # Style.setFrom
    def set_from!(key, other)
      if Keys::STORED.key?(key)
        set!(key, other.__send__(:raw_value, key))
      else
        set!(key, other.__send__(:raw_attrs))
      end
    end

    def raw_value(key) = @values[key]
    def raw_attrs = @attrs

    # Style.Inherit
    def inherit!(other)
      key = Keys::FIRST
      while key <= Keys::LAST
        if other.__send__(:set?, key)
          case key
          when Keys::MARGIN_TOP, Keys::MARGIN_RIGHT, Keys::MARGIN_BOTTOM, Keys::MARGIN_LEFT,
               Keys::PADDING_TOP, Keys::PADDING_RIGHT, Keys::PADDING_BOTTOM, Keys::PADDING_LEFT
            key <<= 1
            next
          when Keys::BACKGROUND
            if !set?(Keys::MARGIN_BACKGROUND) && !other.__send__(:set?, Keys::MARGIN_BACKGROUND)
              set!(Keys::MARGIN_BACKGROUND, other.__send__(:raw_value, Keys::BACKGROUND))
            end
          end
          set_from!(key, other) unless set?(key)
        end
        key <<= 1
      end
    end

    # whichSidesInt + Padding / Margin
    def set_sides!(kind, sides)
      return unless (1..4).cover?(sides.length)

      top, right, bottom, left = which_sides(sides)

      if kind == :padding
        set!(Keys::PADDING_TOP, top)
        set!(Keys::PADDING_RIGHT, right)
        set!(Keys::PADDING_BOTTOM, bottom)
        set!(Keys::PADDING_LEFT, left)
      else
        set!(Keys::MARGIN_TOP, top)
        set!(Keys::MARGIN_RIGHT, right)
        set!(Keys::MARGIN_BOTTOM, bottom)
        set!(Keys::MARGIN_LEFT, left)
      end
    end

    # BorderForeground(c...) / BorderBackground(c...)
    def set_border_colors!(kind, colors)
      return if colors.empty?
      return unless (1..4).cover?(colors.length)

      top, right, bottom, left = which_sides(colors)
      if kind == :foreground
        set!(Keys::BORDER_TOP_FOREGROUND, top)
        set!(Keys::BORDER_RIGHT_FOREGROUND, right)
        set!(Keys::BORDER_BOTTOM_FOREGROUND, bottom)
        set!(Keys::BORDER_LEFT_FOREGROUND, left)
      else
        set!(Keys::BORDER_TOP_BACKGROUND, top)
        set!(Keys::BORDER_RIGHT_BACKGROUND, right)
        set!(Keys::BORDER_BOTTOM_BACKGROUND, bottom)
        set!(Keys::BORDER_LEFT_BACKGROUND, left)
      end
    end

    # whichSides*: [top, right, bottom, left], or [] when the count isn't 1..4.
    def which_sides(i)
      case i.length
      when 1 then [i[0], i[0], i[0], i[0]]
      when 2 then [i[0], i[1], i[0], i[1]]
      when 3 then [i[0], i[1], i[2], i[1]]
      when 4 then [i[0], i[1], i[2], i[3]]
      else []
      end
    end

    # --- Go getters ------------------------------------------------------------------------------

    def get_as_bool(key, default)
      return default unless set?(key)

      (@attrs & key) != 0
    end

    def get_as_color(key)
      return NO_COLOR unless set?(key)

      @values[key] || NO_COLOR
    end

    def get_as_int(key)
      return 0 unless set?(key)

      @values[key] || 0
    end

    def get_as_position(key)
      return 0.0 unless set?(key)

      @values[key] || 0.0
    end

    def get_border_style
      return Gloss::Borders::NO_BORDER unless set?(Keys::BORDER_STYLE)

      @values[Keys::BORDER_STYLE]
    end

    def implicit_borders?
      get_border_style != Gloss::Borders::NO_BORDER &&
        !(set?(Keys::BORDER_TOP) || set?(Keys::BORDER_RIGHT) || set?(Keys::BORDER_BOTTOM) || set?(Keys::BORDER_LEFT))
    end

    def get_padding
      [get_as_int(Keys::PADDING_TOP), get_as_int(Keys::PADDING_RIGHT),
       get_as_int(Keys::PADDING_BOTTOM), get_as_int(Keys::PADDING_LEFT)]
    end

    def get_margin
      [get_as_int(Keys::MARGIN_TOP), get_as_int(Keys::MARGIN_RIGHT),
       get_as_int(Keys::MARGIN_BOTTOM), get_as_int(Keys::MARGIN_LEFT)]
    end

    def get_horizontal_padding = get_as_int(Keys::PADDING_LEFT) + get_as_int(Keys::PADDING_RIGHT)
    def get_vertical_padding = get_as_int(Keys::PADDING_TOP) + get_as_int(Keys::PADDING_BOTTOM)
    def get_horizontal_margins = get_as_int(Keys::MARGIN_LEFT) + get_as_int(Keys::MARGIN_RIGHT)
    def get_vertical_margins = get_as_int(Keys::MARGIN_TOP) + get_as_int(Keys::MARGIN_BOTTOM)

    def get_border
      [get_border_style, get_as_bool(Keys::BORDER_TOP, false), get_as_bool(Keys::BORDER_RIGHT, false),
       get_as_bool(Keys::BORDER_BOTTOM, false), get_as_bool(Keys::BORDER_LEFT, false)]
    end

    def get_border_top_size
      return 0 if !get_as_bool(Keys::BORDER_TOP, false) && !implicit_borders?

      get_border_style.top_size
    end

    def get_border_right_size
      return 0 if !get_as_bool(Keys::BORDER_RIGHT, false) && !implicit_borders?

      get_border_style.right_size
    end

    def get_border_bottom_size
      return 0 if !get_as_bool(Keys::BORDER_BOTTOM, false) && !implicit_borders?

      get_border_style.bottom_size
    end

    def get_border_left_size
      return 0 if !get_as_bool(Keys::BORDER_LEFT, false) && !implicit_borders?

      get_border_style.left_size
    end

    def get_horizontal_border_size = get_border_left_size + get_border_right_size
    def get_vertical_border_size = get_border_top_size + get_border_bottom_size
    def get_horizontal_frame_size = get_horizontal_margins + get_horizontal_padding + get_horizontal_border_size
    def get_vertical_frame_size = get_vertical_margins + get_vertical_padding + get_vertical_border_size

    def get_align_horizontal = get_as_position(Keys::ALIGN_HORIZONTAL)
    def get_align_vertical = get_as_position(Keys::ALIGN_VERTICAL)
    def get_max_width = get_as_int(Keys::MAX_WIDTH)
    def get_max_height = get_as_int(Keys::MAX_HEIGHT)
    def get_inline = get_as_bool(Keys::INLINE, false)

    # --- Go setters for the table / list / tree ports -------------------------------------------

    # Border(b, sides...)
    def set_border_def(border_def, *sides)
      b = border_def.normalized.freeze
      derive do |s|
        s.__send__(:set!, Keys::BORDER_STYLE, b)
        top, right, bottom, left = (1..4).cover?(sides.length) ? s.__send__(:which_sides, sides) : [true] * 4
        s.__send__(:set!, Keys::BORDER_TOP, top ? true : false)
        s.__send__(:set!, Keys::BORDER_RIGHT, right ? true : false)
        s.__send__(:set!, Keys::BORDER_BOTTOM, bottom ? true : false)
        s.__send__(:set!, Keys::BORDER_LEFT, left ? true : false)
      end
    end

    # BorderStyle(b)
    def set_border_style_def(border_def)
      with(Keys::BORDER_STYLE, border_def.normalized.freeze)
    end

    def set_foreground_color(terminal_color) = with(Keys::FOREGROUND, terminal_color)
    def set_background_color(terminal_color) = with(Keys::BACKGROUND, terminal_color)

    # --- Ruby argument conversions (C extension) -------------------------------------------------

    def num2int(value) = Gloss::Layout.num2int(value)

    def spacing_args(values)
      if values.empty? || values.length > 4
        raise ArgumentError, "wrong number of arguments (given #{values.length}, expected 1..4)"
      end

      values.map { |v| num2int(v) }
    end

    def side_color(color)
      Gloss::Renderer.terminal_color(color, adaptive: false, complete: false)
    end

    # terminalColorToString in go/style.go: only a plain Color has a string.
    def color_string(color)
      return nil unless color.is_a?(Gloss::TerminalColor::Color)
      return nil if color.value.nil? || color.value.empty?

      String.new(color.value, encoding: UTF_8)
    end

    def utf8(str)
      str.b.force_encoding(UTF_8)
    end

    # StringValueCStr, then the bytes C (and Go's C.GoString) sees, as a UTF-8 string. For an
    # ASCII-incompatible encoding (UTF-16, UTF-32) Ruby only rejects a NUL character, and C stops
    # at the first NUL byte.
    def c_str(value)
      str = String.try_convert(value)
      return utf8(Gloss::Layout.c_string(value)) if str.nil? || str.encoding.ascii_compatible?

      nul = begin
        "\0".encode(str.encoding)
      rescue EncodingError
        nil
      end
      raise ArgumentError, "string contains null byte" if nul && str.b.include?(nul.b) && str.include?(nul)

      b = str.b
      cut = b.index("\0")
      utf8(cut ? b.byteslice(0, cut) : b)
    end

    # rb_utf8_str_new_cstr: a fresh, unfrozen UTF-8 string.
    def c_result(str)
      String.new(str, encoding: UTF_8)
    end

    NO_COLOR = Gloss::TerminalColor::NoColor.new.freeze
    RIGHT = 1.0
    CENTER = 0.5
    BOTTOM = 1.0
    TOP = 0.0
    private_constant :NO_COLOR, :RIGHT, :CENTER, :BOTTOM, :TOP

    def no_color?(color) = color.is_a?(Gloss::TerminalColor::NoColor)

    # --- Render (style.go) -----------------------------------------------------------------------

    def go_render(*strs)
      strs = [@value, *strs] unless @value.empty?
      str = strs.map { |x| utf8(x) }.join(" ")

      r = Gloss::Renderer.default
      p = r.color_profile
      te = p.string
      te_space = p.string
      te_whitespace = p.string

      bold = get_as_bool(Keys::BOLD, false)
      italic = get_as_bool(Keys::ITALIC, false)
      underline = get_as_bool(Keys::UNDERLINE, false)
      strikethrough = get_as_bool(Keys::STRIKETHROUGH, false)
      reverse = get_as_bool(Keys::REVERSE, false)
      blink = get_as_bool(Keys::BLINK, false)
      faint = get_as_bool(Keys::FAINT, false)

      fg = get_as_color(Keys::FOREGROUND)
      bg = get_as_color(Keys::BACKGROUND)

      width = get_as_int(Keys::WIDTH)
      height = get_as_int(Keys::HEIGHT)
      horizontal_align = get_as_position(Keys::ALIGN_HORIZONTAL)
      vertical_align = get_as_position(Keys::ALIGN_VERTICAL)

      top_padding = get_as_int(Keys::PADDING_TOP)
      right_padding = get_as_int(Keys::PADDING_RIGHT)
      bottom_padding = get_as_int(Keys::PADDING_BOTTOM)
      left_padding = get_as_int(Keys::PADDING_LEFT)

      color_whitespace = get_as_bool(Keys::COLOR_WHITESPACE, true)
      inline = get_as_bool(Keys::INLINE, false)
      max_width = get_as_int(Keys::MAX_WIDTH)
      max_height = get_as_int(Keys::MAX_HEIGHT)

      underline_spaces = get_as_bool(Keys::UNDERLINE_SPACES, false) ||
                         (underline && get_as_bool(Keys::UNDERLINE_SPACES, true))
      strikethrough_spaces = get_as_bool(Keys::STRIKETHROUGH_SPACES, false) ||
                             (strikethrough && get_as_bool(Keys::STRIKETHROUGH_SPACES, true))

      style_whitespace = reverse
      use_space_styler = (underline && !underline_spaces) || (strikethrough && !strikethrough_spaces) ||
                         underline_spaces || strikethrough_spaces

      return maybe_convert_tabs(str) if @props.zero?

      te = te.bold if bold
      te = te.italic if italic
      te = te.underline if underline
      if reverse
        te_whitespace = te_whitespace.reverse
        te = te.reverse
      end
      te = te.blink if blink
      te = te.faint if faint

      unless no_color?(fg)
        te = te.foreground(fg.color(r))
        te_whitespace = te_whitespace.foreground(fg.color(r)) if style_whitespace
        te_space = te_space.foreground(fg.color(r)) if use_space_styler
      end

      unless no_color?(bg)
        te = te.background(bg.color(r))
        te_whitespace = te_whitespace.background(bg.color(r)) if color_whitespace
        te_space = te_space.background(bg.color(r)) if use_space_styler
      end

      te = te.underline if underline
      te = te.cross_out if strikethrough

      te_space = te_space.underline if underline_spaces
      te_space = te_space.cross_out if strikethrough_spaces

      str = maybe_convert_tabs(str)
      str = replace_all(str, "\r\n", "\n")
      str = replace_all(str, "\n", "") if inline

      if !inline && width.positive?
        wrap_at = width - left_padding - right_padding
        str = Gloss::Text.cellbuf_wrap(str, wrap_at, "")
      end

      # Render core text
      lines = go_split(str)
      out = +""
      lines.each_with_index do |line, i|
        if use_space_styler
          each_rune(line) do |rune, ch|
            out << (Gloss::Text.space?(rune) ? te_space.styled(ch) : te.styled(ch))
          end
        else
          out << te.styled(line)
        end
        out << "\n" if i != lines.length - 1
      end
      str = out

      ws_style = color_whitespace || style_whitespace ? te_whitespace : nil

      unless inline
        str = pad(str, -left_padding, ws_style) if left_padding.positive?
        str = pad(str, right_padding, ws_style) if right_padding.positive?
        str = ("\n" * top_padding) + str if top_padding.positive?
        str += "\n" * bottom_padding if bottom_padding.positive?
      end

      str = align_text_vertical(str, vertical_align, height) if height.positive?

      num_lines = str.b.count("\n")
      str = align_text_horizontal(str, horizontal_align, width, ws_style) if num_lines != 0 || width != 0

      unless inline
        str = apply_border(str)
        str = apply_margins(str, inline)
      end

      if max_width.positive?
        str = go_split(str).map { |l| Gloss::Text.truncate(l, max_width, "") }.join("\n")
      end

      if max_height.positive?
        lines = go_split(str)
        h = [max_height, lines.length].min
        str = lines[0, h].join("\n") unless lines.empty?
      end

      str
    end

    def maybe_convert_tabs(str)
      tw = set?(Keys::TAB_WIDTH) ? get_as_int(Keys::TAB_WIDTH) : TAB_WIDTH_DEFAULT
      case tw
      when -1 then str
      when 0 then replace_all(str, "\t", "")
      else replace_all(str, "\t", " " * tw)
      end
    end

    def apply_margins(str, inline)
      top_margin = get_as_int(Keys::MARGIN_TOP)
      right_margin = get_as_int(Keys::MARGIN_RIGHT)
      bottom_margin = get_as_int(Keys::MARGIN_BOTTOM)
      left_margin = get_as_int(Keys::MARGIN_LEFT)

      styler = Gloss::Termenv::Style.new
      bgc = get_as_color(Keys::MARGIN_BACKGROUND)
      styler = styler.background(bgc.color(Gloss::Renderer.default)) unless no_color?(bgc)

      str = pad(str, -left_margin, styler)
      str = pad(str, right_margin, styler)

      unless inline
        _lines, width = get_lines(str)
        spaces = " " * width
        str = styler.styled("#{spaces}\n" * top_margin) + str if top_margin.positive?
        str += styler.styled("\n#{spaces}" * bottom_margin) if bottom_margin.positive?
      end

      str
    end

    def pad(str, n, style)
      return str if n.zero?

      sp = " " * n.abs
      sp = style.styled(sp) if style

      lines = go_split(str)
      out = +""
      lines.each_with_index do |l, i|
        if n.positive?
          out << l << sp
        else
          out << sp << l
        end
        out << "\n" if i != lines.length - 1
      end
      out
    end

    # --- align.go --------------------------------------------------------------------------------

    def align_text_horizontal(str, pos, width, style)
      lines, widest = get_lines(str)
      out = +""
      lines.each_with_index do |l, i|
        line_width = Gloss::Text.string_width(l)
        short = widest - line_width
        short += [0, width - (short + line_width)].max
        if short.positive?
          if pos == RIGHT
            s = " " * short
            s = style.styled(s) if style
            l = s + l
          elsif pos == CENTER
            left = short / 2
            right = left + (short % 2)
            left_spaces = " " * left
            right_spaces = " " * right
            if style
              left_spaces = style.styled(left_spaces)
              right_spaces = style.styled(right_spaces)
            end
            l = left_spaces + l + right_spaces
          else
            s = " " * short
            s = style.styled(s) if style
            l += s
          end
        end
        out << l
        out << "\n" if i < lines.length - 1
      end
      out
    end

    def align_text_vertical(str, pos, height)
      str_height = str.b.count("\n") + 1
      return str if height < str_height

      if pos == TOP
        str + ("\n" * (height - str_height))
      elsif pos == CENTER
        top_padding = (height - str_height) / 2
        bottom_padding = top_padding
        if str_height + top_padding + bottom_padding > height
          top_padding -= 1
        elsif str_height + top_padding + bottom_padding < height
          bottom_padding += 1
        end
        ("\n" * top_padding) + str + ("\n" * bottom_padding)
      elsif pos == BOTTOM
        ("\n" * (height - str_height)) + str
      else
        str
      end
    end

    # --- borders.go ------------------------------------------------------------------------------

    def apply_border(str)
      border = get_border_style.dup
      has_top = get_as_bool(Keys::BORDER_TOP, false)
      has_right = get_as_bool(Keys::BORDER_RIGHT, false)
      has_bottom = get_as_bool(Keys::BORDER_BOTTOM, false)
      has_left = get_as_bool(Keys::BORDER_LEFT, false)

      top_fg = get_as_color(Keys::BORDER_TOP_FOREGROUND)
      right_fg = get_as_color(Keys::BORDER_RIGHT_FOREGROUND)
      bottom_fg = get_as_color(Keys::BORDER_BOTTOM_FOREGROUND)
      left_fg = get_as_color(Keys::BORDER_LEFT_FOREGROUND)

      top_bg = get_as_color(Keys::BORDER_TOP_BACKGROUND)
      right_bg = get_as_color(Keys::BORDER_RIGHT_BACKGROUND)
      bottom_bg = get_as_color(Keys::BORDER_BOTTOM_BACKGROUND)
      left_bg = get_as_color(Keys::BORDER_LEFT_BACKGROUND)

      if implicit_borders?
        has_top = true
        has_right = true
        has_bottom = true
        has_left = true
      end

      return str if border == Gloss::Borders::NO_BORDER || (!has_top && !has_right && !has_bottom && !has_left)

      lines, width = get_lines(str)

      if has_left
        border.left = " " if border.left.empty?
        width += Gloss::Borders.max_rune_width(border.left)
      end

      border.right = " " if has_right && border.right.empty?
      border.top_left = " " if has_top && has_left && border.top_left.empty?
      border.top_right = " " if has_top && has_right && border.top_right.empty?
      border.bottom_left = " " if has_bottom && has_left && border.bottom_left.empty?
      border.bottom_right = " " if has_bottom && has_right && border.bottom_right.empty?

      if has_top
        if !has_left && !has_right
          border.top_left = ""
          border.top_right = ""
        elsif !has_left
          border.top_left = ""
        elsif !has_right
          border.top_right = ""
        end
      end

      if has_bottom
        if !has_left && !has_right
          border.bottom_left = ""
          border.bottom_right = ""
        elsif !has_left
          border.bottom_left = ""
        elsif !has_right
          border.bottom_right = ""
        end
      end

      border.top_left = first_rune(border.top_left)
      border.top_right = first_rune(border.top_right)
      border.bottom_right = first_rune(border.bottom_right)
      border.bottom_left = first_rune(border.bottom_left)

      out = +""
      if has_top
        top = render_horizontal_edge(border.top_left, border.top, border.top_right, width)
        out << style_border(top, top_fg, top_bg) << "\n"
      end

      left_runes = go_runes(border.left)
      left_index = 0
      right_runes = go_runes(border.right)
      right_index = 0

      lines.each_with_index do |l, i|
        if has_left
          ch = left_runes[left_index]
          left_index += 1
          left_index = 0 if left_index >= left_runes.length
          out << style_border(ch, left_fg, left_bg)
        end
        out << l
        if has_right
          ch = right_runes[right_index]
          right_index += 1
          right_index = 0 if right_index >= right_runes.length
          out << style_border(ch, right_fg, right_bg)
        end
        out << "\n" if i < lines.length - 1
      end

      if has_bottom
        bottom = render_horizontal_edge(border.bottom_left, border.bottom, border.bottom_right, width)
        out << "\n" << style_border(bottom, bottom_fg, bottom_bg)
      end

      out
    end

    def render_horizontal_edge(left, middle, right, width)
      middle = " " if middle.empty?
      left_width = Gloss::Text.string_width(left)
      right_width = Gloss::Text.string_width(right)

      runes = go_runes(middle)
      widths = runes.map { |ch| Gloss::Text.string_width(ch) }
      j = 0
      out = +""
      out << left
      i = left_width + right_width
      # Go loops forever when every rune of the edge is zero-width; stop instead.
      if widths.any?(&:positive?)
        while i < width + right_width
          out << runes[j]
          j += 1
          j = 0 if j >= runes.length
          i += widths[j]
        end
      end
      out << right
      out
    end

    def style_border(border, fg, bg)
      return border if no_color?(fg) && no_color?(bg)

      r = Gloss::Renderer.default
      style = Gloss::Termenv::Style.new
      style = style.foreground(fg.color(r)) unless no_color?(fg)
      style = style.background(bg.color(r)) unless no_color?(bg)
      style.styled(border)
    end

    def first_rune(str)
      return str if str.empty?

      go_runes(str).first
    end

    # --- Go string helpers -----------------------------------------------------------------------

    # strings.Split(s, "\n")
    def go_split(str)
      return [+""] if str.empty?

      str.b.split("\n", -1).map { |l| l.force_encoding(UTF_8) }
    end

    # strings.ReplaceAll on bytes.
    def replace_all(str, from, to)
      b = str.b
      return str unless b.include?(from)

      b.gsub(from.b, to.b).force_encoding(UTF_8)
    end

    # getLines
    def get_lines(str)
      lines = go_split(str)
      widest = 0
      lines.each do |l|
        w = Gloss::Text.string_width(l)
        widest = w if widest < w
      end
      [lines, widest]
    end

    # Ranges over a Go string: yields [rune, utf-8 string]; invalid bytes yield U+FFFD.
    def each_rune(str)
      if str.ascii_only?
        str.each_char { |ch| yield ch.ord, ch }
        return
      end

      b = str.b
      n = b.bytesize
      i = 0
      while i < n
        r, size = Gloss::Text.decode_rune(b, i, n)
        yield r, (r < 0x80 ? r.chr : [r].pack("U"))
        i += size
      end
    end

    # []rune(s) as strings.
    def go_runes(str)
      out = []
      each_rune(str) { |_r, ch| out << ch }
      out
    end
  end
end
