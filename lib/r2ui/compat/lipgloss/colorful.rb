# frozen_string_literal: true

module R2UI
  module Compat
    module Gloss
      # Port of the parts of lucasb-eyer/go-colorful v1.2.0 that lipgloss and termenv use: hex parsing
      # and formatting, RGB/Luv/HCL blending, HSL, and the HSLuv distance termenv uses to pick the
      # nearest ANSI/ANSI256 color.
      #
      #   c = Colorful.hex("#ff8000")   # => Colorful::Color, or nil where Go returns an error
      #   c.blend_luv(other, 0.5).hex   # => "#rrggbb"
      #
      # Float fidelity: the gem ships Go code compiled for arm64, where the Go compiler fuses `a + x*y`,
      # `a - x*y` and `x*y - a` into single-rounding FMA instructions, and evaluates constant
      # expressions exactly. The formulas below spell out each fused operation (GoMath.madd/msub/nmsub)
      # and use exactly folded constants, so blends land on the same side of rounding ties as the gem.
      module Colorful
        # Float helpers reproducing how Go computes on arm64.
        module GoMath
          module_function

          # Correctly rounded x*y + z (one rounding, like the FMADD instruction).
          def fma(x, y, z)
            return x * y + z unless x.finite? && y.finite? && z.finite?
            return x * y + z if x.zero? || y.zero?

            mx, ex = split(x)
            my, ey = split(y)
            mz, ez = split(z)
            mp = mx * my
            ep = ex + ey
            return round_scaled(mp, ep) if mz.zero?

            e = ep < ez ? ep : ez
            round_scaled((mp << (ep - e)) + (mz << (ez - e)), e)
          end

          # a + x*y, fused.
          def madd(a, x, y)
            fma(x, y, a)
          end

          # a - x*y, fused.
          def msub(a, x, y)
            fma(-x, y, a)
          end

          # x*y - a, fused.
          def nmsub(x, y, a)
            fma(x, y, -a)
          end

          # Exact integer mantissa and exponent: f == m * 2**e.
          def split(f)
            return [0, 0] if f.zero?

            frac, exp = Math.frexp(f)
            [Math.ldexp(frac, 53).to_i, exp - 53]
          end

          # Round m * 2**e to the nearest float, ties to even.
          def round_scaled(m, e)
            return 0.0 if m.zero?

            sign = m.negative? ? -1.0 : 1.0
            m = m.abs
            shift = m.bit_length - 53
            if shift.positive?
              q = m >> shift
              rem = m & ((1 << shift) - 1)
              half = 1 << (shift - 1)
              q += 1 if rem > half || (rem == half && q.odd?)
              sign * Math.ldexp(q.to_f, e + shift)
            else
              sign * Math.ldexp(m.to_f, e)
            end
          end

          # math.Mod: like C fmod, exact, and the result takes the sign of x.
          def mod(x, y)
            r = x.abs % y.abs
            x.negative? ? -r : r
          end

          # math.Pow as Go implements it: x**frac via Exp(frac*Log(x)), then the integer part by
          # repeated squaring of the Frexp mantissa (each product rounded), finally Ldexp.
          def pow(x, y)
            return 1.0 if y.zero? || x == 1.0
            return x if y == 1.0
            return Float::NAN if x.nan? || y.nan?
            return x**y if x.zero? || x.infinite? || y.infinite?
            return Math.sqrt(x) if y == 0.5
            return 1 / Math.sqrt(x) if y == -0.5

            yi = y.abs.floor.to_f
            yf = y.abs - yi
            return Float::NAN if yf != 0 && x.negative?

            a1 = 1.0
            ae = 0
            if yf != 0
              if yf > 0.5
                yf -= 1
                yi += 1
              end
              a1 = Math.exp(yf * Math.log(x))
            end
            x1, xe = Math.frexp(x)
            i = yi.to_i
            while i != 0
              if xe < -(1 << 12) || (1 << 12) < xe
                ae += xe
                break
              end
              if i.odd?
                a1 *= x1
                ae += xe
              end
              x1 *= x1
              xe <<= 1
              if x1 < 0.5
                x1 += x1
                xe -= 1
              end
              i >>= 1
            end
            if y.negative?
              a1 = 1 / a1
              ae = -ae
            end
            Math.ldexp(a1, ae)
          end

          CBRT_B1 = 715_094_163
          CBRT_B2 = 696_219_795
          CBRT_C = 5.42857142857142815906e-01
          CBRT_D = -7.05306122448979611050e-01
          CBRT_E = 1.41428571428571436819e+00
          CBRT_F = 1.60714285714285720630e+00
          CBRT_G = 3.57142857142857150787e-01
          SMALLEST_NORMAL = 2.22507385850720138309e-308

          # math.Cbrt (pure Go, FreeBSD s_cbrt.c), with arm64's fused multiply-adds.
          def cbrt(x)
            return x if x.zero? || x.nan? || x.infinite?

            sign = x.negative?
            x = -x if sign
            t = from_bits(bits(x) / 3 + (CBRT_B1 << 32))
            if x < SMALLEST_NORMAL
              t = (1 << 54).to_f * x
              t = from_bits(bits(t) / 3 + (CBRT_B2 << 32))
            end
            r = t * t / x
            s = madd(CBRT_C, r, t)
            t *= CBRT_G + CBRT_F / (s + CBRT_E + CBRT_D / s)
            t = from_bits((bits(t) & (0xFFFFFFFFC << 28)) + (1 << 30))
            s = t * t
            r = x / s
            w = t + t
            r = (r - t) / (w + r)
            t = madd(t, t, r)
            sign ? -t : t
          end

          def bits(f)
            [f].pack("G").unpack1("Q>")
          end

          def from_bits(i)
            [i & 0xFFFF_FFFF_FFFF_FFFF].pack("Q>").unpack1("G")
          end
        end

        extend GoMath

        D65 = [0.95047, 1.00000, 1.08883].freeze
        HSLUV_D65 = [0.95045592705167, 1.0, 1.089057750759878].freeze

        # Go constant expressions are folded exactly, then rounded once.
        LAB_EPS = Rational(216, 24_389).to_f      # 6.0/29.0*6.0/29.0*6.0/29.0
        LAB_6_29 = Rational(6, 29).to_f           # 6.0/29.0
        LAB_4_29 = Rational(4, 29).to_f           # 4.0/29.0
        LAB_FINV_K = Rational(108, 841).to_f      # 3.0*6.0/29.0*6.0/29.0
        LUV_KAPPA = Rational(24_389, 27).to_f     # 29.0/3.0*29.0/3.0*29.0/3.0
        ONE_THIRD = Rational(1, 3).to_f
        TWO_THIRDS = Rational(2, 3).to_f
        INV_GAMMA = Rational(5, 12).to_f # 1.0/2.4
        RAD2DEG = 57.29577951308232087721
        DEG2RAD = 0.01745329251994329576

        # Go's fmt scanning treats these as space (fmt/scan.go `space` table).
        SPACE_RANGES = [
          [0x0009, 0x000d], [0x0020, 0x0020], [0x0085, 0x0085], [0x00a0, 0x00a0], [0x1680, 0x1680],
          [0x2000, 0x200a], [0x2028, 0x2029], [0x202f, 0x202f], [0x205f, 0x205f], [0x3000, 0x3000]
        ].freeze
        HEX_SCAN_DIGITS = "0123456789aAbBcCdDeEfF_"

        module_function

        # colorful.Hex: parses "#rrggbb", or "#rgb" when the string is 4 bytes long. Mirrors
        # fmt.Sscanf(scol, "#%02x%02x%02x") exactly, including its quirks: spaces before a number are
        # skipped, a short final component is accepted ("#12345"), and trailing input is ignored
        # ("#ffffffzz"). Returns nil where Go returns an error.
        def hex(scol)
          scol = scol.to_s
          width = 2
          factor = 1.0 / 255.0
          if scol.bytesize == 4
            width = 1
            factor = 1.0 / 15.0
          end

          runes = go_runes(scol)
          return nil unless runes[0] == 0x23 # '#'

          pos = 1
          values = []
          3.times do
            value, pos = scan_hex_uint8(runes, pos, width)
            return nil if value.nil?

            values << value
          end

          Color.new(values[0] * factor, values[1] * factor, values[2] * factor)
        end

        # One "%0Nx" verb into a uint8, as fmt's doScanf/scanUint do it: SkipSpace (not counted in the
        # width), notEOF, then up to `width` runes of hex digits or '_', parsed with strconv.ParseUint.
        def scan_hex_uint8(runes, pos, width)
          while pos < runes.size
            r = runes[pos]
            if r == 0x0d && runes[pos + 1] == 0x0a
              pos += 1
              next
            end
            return [nil, pos] if r == 0x0a # "unexpected newline"
            break unless go_space?(r)

            pos += 1
          end
          return [nil, pos] if pos >= runes.size # notEOF

          limit = pos + width
          start = pos
          pos += 1 while pos < limit && pos < runes.size && runes[pos] < 0x80 && HEX_SCAN_DIGITS.include?(runes[pos].chr)
          return [nil, pos] if pos == start # "expected integer"

          token = runes[start...pos].pack("U*")
          return [nil, pos] if token.include?("_") # ParseUint with base 16 rejects underscores

          [token.to_i(16), pos]
        end

        def go_space?(r)
          SPACE_RANGES.any? { |lo, hi| r >= lo && r <= hi }
        end

        # Go decodes strings as UTF-8, turning each invalid byte into U+FFFD.
        def go_runes(str)
          str.b.force_encoding(Encoding::UTF_8).scrub("�").codepoints
        end

        # math.Max(0, math.Min(v, 1)); NaN stays NaN as in Go.
        def clamp01(v)
          return v if v.nan?

          v = 1.0 if v > 1.0
          v < 0.0 ? 0.0 : v
        end

        # Go's uint8(float64) as compiled on arm64 (the gem's platform): a saturating conversion to
        # int32 (FCVTZS, NaN -> 0), then the low 8 bits. So -2.0 * 255 + 0.5 wraps to 3, while huge
        # values and +Inf give 0xff. Observed from the real gem.
        def go_uint8(f)
          return 0 if f.nan?
          return 0xff if f >= 2_147_483_647
          return 0 if f <= -2_147_483_648

          f.to_i & 0xff
        end

        def interp_angle(a0, a1, t)
          delta = mod(mod(a1 - a0, 360.0) + 540, 360.0) - 180.0
          mod(madd(a0, t, delta) + 360.0, 360.0)
        end

        def linearize(v)
          return v / 12.92 if v <= 0.04045

          pow((v + 0.055) / 1.055, 2.4)
        end

        def delinearize(v)
          return 12.92 * v if v <= 0.0031308

          nmsub(1.055, pow(v, INV_GAMMA), 0.055)
        end

        def linear_rgb(r, g, b)
          Color.new(delinearize(r), delinearize(g), delinearize(b))
        end

        def xyz_to_linear_rgb(x, y, z)
          [
            msub(msub(3.2409699419045214 * x, 1.5373831775700935, y), 0.49861076029300328, z),
            madd(madd(-0.96924363628087983 * x, 1.8759675015077207, y), 0.041555057407175613, z),
            madd(msub(0.055630079696993609 * x, 0.20397695888897657, y), 1.0569715142428786, z)
          ]
        end

        def linear_rgb_to_xyz(r, g, b)
          [
            madd(madd(0.41239079926595948 * r, 0.35758433938387796, g), 0.18048078840183429, b),
            madd(madd(0.21263900587151036 * r, 0.71516867876775593, g), 0.072192315360733715, b),
            madd(madd(0.019330818715591851 * r, 0.11919477979462599, g), 0.95053215224966058, b)
          ]
        end

        def xyz(x, y, z)
          linear_rgb(*xyz_to_linear_rgb(x, y, z))
        end

        def lab_f(t)
          return cbrt(t) if t > LAB_EPS

          t / 3.0 * 29.0 / 6.0 * 29.0 / 6.0 + LAB_4_29
        end

        def lab_finv(t)
          return t * t * t if t > LAB_6_29

          LAB_FINV_K * (t - LAB_4_29)
        end

        def xyz_to_lab_white_ref(x, y, z, wref)
          fy = lab_f(y / wref[1])
          [nmsub(1.16, fy, 0.16), 5.0 * (lab_f(x / wref[0]) - fy), 2.0 * (fy - lab_f(z / wref[2]))]
        end

        def lab_to_xyz_white_ref(l, a, b, wref)
          l2 = (l + 0.16) / 1.16
          [wref[0] * lab_finv(l2 + a / 5.0), wref[1] * lab_finv(l2), wref[2] * lab_finv(l2 - b / 2.0)]
        end

        def lab_white_ref(l, a, b, wref)
          xyz(*lab_to_xyz_white_ref(l, a, b, wref))
        end

        def xyz_to_uv(x, y, z)
          denom = madd(madd(x, 15.0, y), 3.0, z)
          return [0.0, 0.0] if denom == 0.0

          [4.0 * x / denom, 9.0 * y / denom]
        end

        def xyz_to_luv_white_ref(x, y, z, wref)
          l = if y / wref[1] <= LAB_EPS
                y / wref[1] * LUV_KAPPA / 100.0
              else
                nmsub(1.16, cbrt(y / wref[1]), 0.16)
              end
          ubis, vbis = xyz_to_uv(x, y, z)
          un, vn = xyz_to_uv(wref[0], wref[1], wref[2])
          [l, 13.0 * l * (ubis - un), 13.0 * l * (vbis - vn)]
        end

        def luv_to_xyz_white_ref(l, u, v, wref)
          y = if l <= 0.08
                wref[1] * l * 100.0 * 3.0 / 29.0 * 3.0 / 29.0 * 3.0 / 29.0
              else
                q = (l + 0.16) / 1.16
                wref[1] * (q * q * q)
              end
          un, vn = xyz_to_uv(wref[0], wref[1], wref[2])
          if l != 0.0
            ubis = u / (13.0 * l) + un
            vbis = v / (13.0 * l) + vn
            x = y * 9.0 * ubis / (4.0 * vbis)
            z = y * msub(msub(12.0, 3.0, ubis), 20.0, vbis) / (4.0 * vbis)
          else
            x = 0.0
            y = 0.0
            z = 0.0
          end
          [x, y, z]
        end

        def luv_white_ref(l, u, v, wref)
          xyz(*luv_to_xyz_white_ref(l, u, v, wref))
        end

        def luv(l, u, v)
          luv_white_ref(l, u, v, D65)
        end

        def lab_to_hcl(l, a, b)
          h = if (b - a).abs > 1e-4 && a.abs > 1e-4
                mod(madd(360.0, RAD2DEG, Math.atan2(b, a)), 360.0)
              else
                0.0
              end
          [h, Math.sqrt(madd(a * a, b, b)), l]
        end

        def hcl_to_lab(h, c, l)
          rad = DEG2RAD * h
          [l, c * Math.cos(rad), c * Math.sin(rad)]
        end

        def hcl(h, c, l)
          lab_white_ref(*hcl_to_lab(h, c, l), D65)
        end

        def luv_to_luv_lch(l, u, v)
          h = if (v - u).abs > 1e-4 && u.abs > 1e-4
                mod(madd(360.0, RAD2DEG, Math.atan2(v, u)), 360.0)
              else
                0.0
              end
          [l, Math.sqrt(madd(u * u, v, v)), h]
        end

        # colorful.Hsl: hue in [0..360], saturation and lightness in [0..1].
        def hsl(h, s, l)
          return Color.new(l, l, l) if s == 0

          t1 = l < 0.5 ? l * (1.0 + s) : msub(l + s, l, s)
          t2 = 2 * l - t1
          h /= 360
          channel = lambda do |t|
            t += 1 if t < 0
            t -= 1 if t > 1
            if 6 * t < 1 then madd(t2, (t1 - t2) * 6, t)
            elsif 2 * t < 1 then t1
            elsif 3 * t < 2 then madd(t2, (t1 - t2) * (TWO_THIRDS - t), 6.0)
            else t2
            end
          end
          Color.new(channel.call(h + ONE_THIRD), channel.call(h), channel.call(h - ONE_THIRD))
        end

        # --- HSLuv (hsluv.go) ---

        M = [
          [3.2409699419045214, -1.5373831775700935, -0.49861076029300328],
          [-0.96924363628087983, 1.8759675015077207, 0.041555057407175613],
          [0.055630079696993609, -0.20397695888897657, 1.0569715142428786]
        ].freeze
        KAPPA = 903.2962962962963
        EPSILON = 0.0088564516790356308

        def luv_lch_to_hsluv(l, c, h)
          c *= 100.0
          l *= 100.0
          s = if l > 99.9999999 || l < 0.00000001
                0.0
              else
                c / max_chroma_for_lh(l, h) * 100.0
              end
          [h, clamp01(s / 100.0), clamp01(l / 100.0)]
        end

        def max_chroma_for_lh(l, h)
          h_rad = h / 360.0 * Math::PI * 2.0
          sin = Math.sin(h_rad)
          cos = Math.cos(h_rad)
          min_length = Float::MAX
          get_bounds(l).each do |x, y|
            length = y / msub(sin, x, cos)
            min_length = length if length > 0.0 && length < min_length
          end
          min_length
        end

        def get_bounds(l)
          sub1 = pow(l + 16.0, 3.0) / 1_560_896.0
          sub2 = sub1 > EPSILON ? sub1 : l / KAPPA
          M.flat_map do |m|
            [0.0, 1.0].map do |k|
              top1 = msub(284_517.0 * m[0], 94_839.0, m[2]) * sub2
              sum = madd(madd(838_422.0 * m[2], 769_860.0, m[1]), 731_718.0, m[0])
              top2 = msub(sum * l * sub2, 769_860.0 * k, l)
              bottom = madd(msub(632_260.0 * m[2], 126_452.0, m[1]) * sub2, 126_452.0, k)
              [top1 / bottom, top2 / bottom]
            end
          end
        end

        # A color in sRGB, each channel nominally in [0..1] (blends may leave the gamut).
        Color = Struct.new(:r, :g, :b) do
          include GoMath

          # Color.Hex: "#rrggbb" with Go's +0.5 rounding and uint8 conversion.
          def hex
            format("#%02x%02x%02x", *rgb255)
          end

          def rgb255
            [Colorful.go_uint8(madd(0.5, r, 255.0)), Colorful.go_uint8(madd(0.5, g, 255.0)),
             Colorful.go_uint8(madd(0.5, b, 255.0))]
          end

          def clamped
            Color.new(Colorful.clamp01(r), Colorful.clamp01(g), Colorful.clamp01(b))
          end

          def linear_rgb
            [Colorful.linearize(r), Colorful.linearize(g), Colorful.linearize(b)]
          end

          def xyz
            Colorful.linear_rgb_to_xyz(*linear_rgb)
          end

          def lab
            Colorful.xyz_to_lab_white_ref(*xyz, D65)
          end

          def luv_white_ref(wref)
            Colorful.xyz_to_luv_white_ref(*xyz, wref)
          end

          def luv
            luv_white_ref(D65)
          end

          def hcl
            Colorful.lab_to_hcl(*lab)
          end

          def hsl
            min = [[r, g].min, b].min
            max = [[r, g].max, b].max
            l = (max + min) / 2
            return [0.0, 0.0, l] if min == max

            s = l < 0.5 ? (max - min) / (max + min) : (max - min) / (2.0 - max - min)
            h = if max == r then (g - b) / (max - min)
                elsif max == g then 2.0 + (b - r) / (max - min)
                else 4.0 + (r - g) / (max - min)
                end
            h *= 60
            h += 360 if h < 0
            [h, s, l]
          end

          def hsluv
            Colorful.luv_lch_to_hsluv(*Colorful.luv_to_luv_lch(*luv_white_ref(HSLUV_D65)))
          end

          def distance_hsluv(other)
            h1, s1, l1 = hsluv
            h2, s2, l2 = other.hsluv
            dh = (h1 - h2) / 100.0
            Math.sqrt(madd(madd(dh * dh, s1 - s2, s1 - s2), l1 - l2, l1 - l2))
          end

          def distance_luv(other)
            l1, u1, v1 = luv
            l2, u2, v2 = other.luv
            Math.sqrt(madd(madd((l1 - l2) * (l1 - l2), u1 - u2, u1 - u2), v1 - v2, v1 - v2))
          end

          def blend_rgb(other, t)
            Color.new(madd(r, t, other.r - r), madd(g, t, other.g - g), madd(b, t, other.b - b))
          end

          def blend_luv(other, t)
            l1, u1, v1 = luv
            l2, u2, v2 = other.luv
            Colorful.luv(madd(l1, t, l2 - l1), madd(u1, t, u2 - u1), madd(v1, t, v2 - v1))
          end

          def blend_hcl(other, t)
            h1, c1, l1 = hcl
            h2, c2, l2 = other.hcl
            Colorful.hcl(Colorful.interp_angle(h1, h2, t), madd(c1, t, c2 - c1), madd(l1, t, l2 - l1)).clamped
          end
        end
      end
    end
  end
end
