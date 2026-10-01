# frozen_string_literal: true

module Lipgloss
  # Same API as the gem's C extension (ext/lipgloss/color.c) backed by go/color.go: blends of hex
  # colors in Luv, RGB or HCL space.
  module ColorBlend
    LUV = :luv
    RGB = :rgb
    HCL = :hcl

    Colorful = R2UI::Compat::Gloss::Colorful
    private_constant :Colorful

    class << self
      def blend(c1, c2, t, mode: nil, **)
        blend_with(blend_mode(mode), c1, c2, t)
      end

      def blend_luv(c1, c2, t)
        blend_with(LUV, c1, c2, t)
      end

      def blend_rgb(c1, c2, t)
        blend_with(RGB, c1, c2, t)
      end

      def blend_hcl(c1, c2, t)
        blend_with(HCL, c1, c2, t)
      end

      def blends(c1, c2, steps, mode: nil, **)
        check_string(c1)
        check_string(c2)
        mode = blend_mode(mode)
        a = c_string(c1)
        b = c_string(c2)
        n = num2int(steps)
        color1 = Colorful.hex(a)
        return [] if color1.nil?

        color2 = Colorful.hex(b)
        return [] if color2.nil?

        Array.new([n, 0].max) do |i|
          t = n == 1 ? 0.0 : i.to_f / (n - 1).to_f
          mix(mode, color1, color2, t).hex
        end
      end

      def grid(x0y0, x1y0, x0y1, x1y1, x_steps, y_steps, mode: nil, **)
        corners = [x0y0, x1y0, x0y1, x1y1]
        corners.each { |c| check_string(c) }
        mode = blend_mode(mode)
        corners = corners.map { |c| c_string(c) }
        nx = num2int(x_steps)
        ny = num2int(y_steps)
        c00, c10, c01, c11 = corners.map { |c| Colorful.hex(c) || (return []) }

        left = Array.new([ny, 0].max) do |y|
          t = ny == 1 ? 0.0 : y.to_f / ny.to_f
          [mix(mode, c00, c01, t), mix(mode, c10, c11, t)]
        end
        left.map do |x0, x1|
          Array.new([nx, 0].max) do |x|
            t = nx == 1 ? 0.0 : x.to_f / nx.to_f
            mix(mode, x0, x1, t).hex
          end
        end
      end

      private

      # go/color.go lipgloss_color_blend_*: an unparsable color returns c1 unchanged.
      def blend_with(mode, c1, c2, t)
        check_string(c1)
        check_string(c2)
        a = c_string(c1)
        b = c_string(c2)
        t = num2dbl(t)
        color1 = Colorful.hex(a)
        return a.dup.force_encoding(Encoding::UTF_8) if color1.nil?

        color2 = Colorful.hex(b)
        return a.dup.force_encoding(Encoding::UTF_8) if color2.nil?

        mix(mode, color1, color2, t).hex
      end

      def mix(mode, a, b, t)
        case mode
        when RGB then a.blend_rgb(b, t)
        when HCL then a.blend_hcl(b, t)
        else a.blend_luv(b, t)
        end
      end

      # blend_mode_from_symbol: nil and unknown symbols mean LUV; SYM2ID on a non-Symbol raises.
      def blend_mode(mode)
        return LUV if mode.nil?
        raise TypeError, "wrong argument type #{type_name(mode)} (expected Symbol)" unless mode.is_a?(Symbol)

        [LUV, RGB, HCL].include?(mode) ? mode : LUV
      end

      def check_string(value)
        return if value.is_a?(String)

        raise TypeError, "wrong argument type #{type_name(value)} (expected String)"
      end

      def type_name(value)
        case value
        when nil then "nil"
        when true then "true"
        when false then "false"
        else value.class.to_s
        end
      end

      # StringValueCStr: rejects embedded NUL bytes.
      def c_string(str)
        raise ArgumentError, "string contains null byte" if str.include?("\0")

        str
      end

      # NUM2DBL
      def num2dbl(value)
        case value
        when Float then value
        when Numeric then value.to_f
        when String then raise TypeError, "no implicit conversion to float from string"
        when nil, true, false then raise TypeError, "no implicit conversion to float from #{value.inspect}"
        else raise TypeError, "can't convert #{value.class} into Float"
        end
      end

      # NUM2INT
      def num2int(value)
        int = case value
              when Integer then value
              when Float
                raise RangeError, "float #{value} out of range of integer" unless value.finite? && value.abs < 2**63

                value.to_i
              when nil then raise TypeError, "no implicit conversion from nil to integer"
              else
                unless value.respond_to?(:to_int)
                  raise TypeError, "no implicit conversion of #{type_name(value)} into Integer"
                end

                value.to_int
              end
        unless int.between?(-2**31, 2**31 - 1)
          raise RangeError, "integer #{int} too #{int.negative? ? 'small' : 'big'} to convert to 'int'"
        end

        int
      end
    end
  end

  def self.has_dark_background?
    R2UI::Compat::Gloss::Renderer.has_dark_background?
  end
end
