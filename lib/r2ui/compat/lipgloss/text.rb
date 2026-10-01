# frozen_string_literal: true

require_relative "text/unicode_tables"

module R2UI
  module Compat
    module Gloss
      # ANSI-aware text utilities: byte-for-byte ports of what lipgloss v1.1.0 uses from
      # charmbracelet/x/ansi v0.8.0 (StringWidth, Strip, Truncate, TruncateLeft, Cut, Wrap, Hardwrap,
      # Wordwrap, DecodeSequence), charmbracelet/x/cellbuf (Wrap, ReadStyle, ReadLink, Style#Sequence)
      # and rivo/uniseg v0.4.7 (FirstGraphemeCluster and runeWidth).
      #
      # Every function works on the string's bytes exactly like the Go code, so ANSI escape sequences,
      # invalid UTF-8 and C1 control bytes are handled the same way. Results are UTF-8 strings.
      module Text
        # --- DEC ANSI parser transition table (x/ansi/parser/transition_table.go) ---------------------

        GROUND = 0
        CSI_ENTRY = 1
        CSI_INTERMEDIATE = 2
        CSI_PARAM = 3
        DCS_ENTRY = 4
        DCS_INTERMEDIATE = 5
        DCS_PARAM = 6
        DCS_STRING = 7
        ESCAPE = 8
        ESCAPE_INTERMEDIATE = 9
        OSC_STRING = 10
        SOS_STRING = 11
        PM_STRING = 12
        APC_STRING = 13
        UTF8 = 14

        A_NONE = 0
        A_CLEAR = 1
        A_COLLECT = 2
        A_PREFIX = 3
        A_DISPATCH = 4
        A_EXECUTE = 5
        A_START = 6
        A_PUT = 7
        A_PARAM = 8
        A_PRINT = 9

        # Index: state << 8 | byte. Value: action << 4 | next state.
        TABLE = begin
          t = Array.new(4096, (A_NONE << 4) | GROUND)
          one = ->(code, state, action, nxt) { t[(state << 8) | code] = (action << 4) | nxt }
          rng = ->(from, to, state, action, nxt) { (from..to).each { |c| one.(c, state, action, nxt) } }

          (GROUND..UTF8).each do |st|
            [0x18, 0x1a, 0x99, 0x9a].each { |c| one.(c, st, A_EXECUTE, GROUND) }
            rng.(0x80, 0x8F, st, A_EXECUTE, GROUND)
            rng.(0x90, 0x97, st, A_EXECUTE, GROUND)
            one.(0x9C, st, A_EXECUTE, GROUND)
            one.(0x1B, st, A_CLEAR, ESCAPE)
            one.(0x98, st, A_START, SOS_STRING)
            one.(0x9E, st, A_START, PM_STRING)
            one.(0x9F, st, A_START, APC_STRING)
            one.(0x9B, st, A_CLEAR, CSI_ENTRY)
            one.(0x90, st, A_CLEAR, DCS_ENTRY)
            one.(0x9D, st, A_START, OSC_STRING)
            rng.(0xC2, 0xDF, st, A_COLLECT, UTF8)
            rng.(0xE0, 0xEF, st, A_COLLECT, UTF8)
            rng.(0xF0, 0xF4, st, A_COLLECT, UTF8)
          end

          rng.(0x00, 0x17, GROUND, A_EXECUTE, GROUND)
          one.(0x19, GROUND, A_EXECUTE, GROUND)
          rng.(0x1C, 0x1F, GROUND, A_EXECUTE, GROUND)
          rng.(0x20, 0x7E, GROUND, A_PRINT, GROUND)
          one.(0x7F, GROUND, A_EXECUTE, GROUND)

          rng.(0x00, 0x17, ESCAPE_INTERMEDIATE, A_EXECUTE, ESCAPE_INTERMEDIATE)
          one.(0x19, ESCAPE_INTERMEDIATE, A_EXECUTE, ESCAPE_INTERMEDIATE)
          rng.(0x1C, 0x1F, ESCAPE_INTERMEDIATE, A_EXECUTE, ESCAPE_INTERMEDIATE)
          rng.(0x20, 0x2F, ESCAPE_INTERMEDIATE, A_COLLECT, ESCAPE_INTERMEDIATE)
          one.(0x7F, ESCAPE_INTERMEDIATE, A_NONE, ESCAPE_INTERMEDIATE)
          rng.(0x30, 0x7E, ESCAPE_INTERMEDIATE, A_DISPATCH, GROUND)

          rng.(0x00, 0x17, ESCAPE, A_EXECUTE, ESCAPE)
          one.(0x19, ESCAPE, A_EXECUTE, ESCAPE)
          rng.(0x1C, 0x1F, ESCAPE, A_EXECUTE, ESCAPE)
          one.(0x7F, ESCAPE, A_NONE, ESCAPE)
          rng.(0x30, 0x4F, ESCAPE, A_DISPATCH, GROUND)
          rng.(0x51, 0x57, ESCAPE, A_DISPATCH, GROUND)
          one.(0x59, ESCAPE, A_DISPATCH, GROUND)
          one.(0x5A, ESCAPE, A_DISPATCH, GROUND)
          one.(0x5C, ESCAPE, A_DISPATCH, GROUND)
          rng.(0x60, 0x7E, ESCAPE, A_DISPATCH, GROUND)
          rng.(0x20, 0x2F, ESCAPE, A_COLLECT, ESCAPE_INTERMEDIATE)
          one.(0x58, ESCAPE, A_START, SOS_STRING)
          one.(0x5E, ESCAPE, A_START, PM_STRING)
          one.(0x5F, ESCAPE, A_START, APC_STRING)
          one.(0x50, ESCAPE, A_CLEAR, DCS_ENTRY)
          one.(0x5B, ESCAPE, A_CLEAR, CSI_ENTRY)
          one.(0x5D, ESCAPE, A_START, OSC_STRING)

          (SOS_STRING..APC_STRING).each do |st|
            rng.(0x00, 0x17, st, A_PUT, st)
            one.(0x19, st, A_PUT, st)
            rng.(0x1C, 0x1F, st, A_PUT, st)
            rng.(0x20, 0x7F, st, A_PUT, st)
            one.(0x1B, st, A_DISPATCH, ESCAPE)
            one.(0x9C, st, A_DISPATCH, GROUND)
            [0x18, 0x1A].each { |c| one.(c, st, A_NONE, GROUND) }
          end

          rng.(0x00, 0x07, DCS_ENTRY, A_NONE, DCS_ENTRY)
          rng.(0x0E, 0x17, DCS_ENTRY, A_NONE, DCS_ENTRY)
          one.(0x19, DCS_ENTRY, A_NONE, DCS_ENTRY)
          rng.(0x1C, 0x1F, DCS_ENTRY, A_NONE, DCS_ENTRY)
          one.(0x7F, DCS_ENTRY, A_NONE, DCS_ENTRY)
          rng.(0x20, 0x2F, DCS_ENTRY, A_COLLECT, DCS_INTERMEDIATE)
          rng.(0x30, 0x3B, DCS_ENTRY, A_PARAM, DCS_PARAM)
          rng.(0x3C, 0x3F, DCS_ENTRY, A_PREFIX, DCS_PARAM)
          rng.(0x08, 0x0D, DCS_ENTRY, A_PUT, DCS_STRING)
          one.(0x1B, DCS_ENTRY, A_PUT, DCS_STRING)
          rng.(0x40, 0x7E, DCS_ENTRY, A_START, DCS_STRING)

          rng.(0x00, 0x17, DCS_INTERMEDIATE, A_NONE, DCS_INTERMEDIATE)
          one.(0x19, DCS_INTERMEDIATE, A_NONE, DCS_INTERMEDIATE)
          rng.(0x1C, 0x1F, DCS_INTERMEDIATE, A_NONE, DCS_INTERMEDIATE)
          rng.(0x20, 0x2F, DCS_INTERMEDIATE, A_COLLECT, DCS_INTERMEDIATE)
          one.(0x7F, DCS_INTERMEDIATE, A_NONE, DCS_INTERMEDIATE)
          rng.(0x30, 0x3F, DCS_INTERMEDIATE, A_START, DCS_STRING)
          rng.(0x40, 0x7E, DCS_INTERMEDIATE, A_START, DCS_STRING)

          rng.(0x00, 0x17, DCS_PARAM, A_NONE, DCS_PARAM)
          one.(0x19, DCS_PARAM, A_NONE, DCS_PARAM)
          rng.(0x1C, 0x1F, DCS_PARAM, A_NONE, DCS_PARAM)
          rng.(0x30, 0x3B, DCS_PARAM, A_PARAM, DCS_PARAM)
          one.(0x7F, DCS_PARAM, A_NONE, DCS_PARAM)
          rng.(0x3C, 0x3F, DCS_PARAM, A_NONE, DCS_PARAM)
          rng.(0x20, 0x2F, DCS_PARAM, A_COLLECT, DCS_INTERMEDIATE)
          rng.(0x40, 0x7E, DCS_PARAM, A_START, DCS_STRING)

          rng.(0x00, 0x17, DCS_STRING, A_PUT, DCS_STRING)
          one.(0x19, DCS_STRING, A_PUT, DCS_STRING)
          rng.(0x1C, 0x1F, DCS_STRING, A_PUT, DCS_STRING)
          rng.(0x20, 0x7E, DCS_STRING, A_PUT, DCS_STRING)
          one.(0x7F, DCS_STRING, A_PUT, DCS_STRING)
          rng.(0x80, 0xFF, DCS_STRING, A_PUT, DCS_STRING)
          one.(0x1B, DCS_STRING, A_DISPATCH, ESCAPE)
          one.(0x9C, DCS_STRING, A_DISPATCH, GROUND)
          [0x18, 0x1A].each { |c| one.(c, DCS_STRING, A_NONE, GROUND) }

          rng.(0x00, 0x17, CSI_PARAM, A_EXECUTE, CSI_PARAM)
          one.(0x19, CSI_PARAM, A_EXECUTE, CSI_PARAM)
          rng.(0x1C, 0x1F, CSI_PARAM, A_EXECUTE, CSI_PARAM)
          rng.(0x30, 0x3B, CSI_PARAM, A_PARAM, CSI_PARAM)
          one.(0x7F, CSI_PARAM, A_NONE, CSI_PARAM)
          rng.(0x3C, 0x3F, CSI_PARAM, A_NONE, CSI_PARAM)
          rng.(0x40, 0x7E, CSI_PARAM, A_DISPATCH, GROUND)
          rng.(0x20, 0x2F, CSI_PARAM, A_COLLECT, CSI_INTERMEDIATE)

          rng.(0x00, 0x17, CSI_INTERMEDIATE, A_EXECUTE, CSI_INTERMEDIATE)
          one.(0x19, CSI_INTERMEDIATE, A_EXECUTE, CSI_INTERMEDIATE)
          rng.(0x1C, 0x1F, CSI_INTERMEDIATE, A_EXECUTE, CSI_INTERMEDIATE)
          rng.(0x20, 0x2F, CSI_INTERMEDIATE, A_COLLECT, CSI_INTERMEDIATE)
          one.(0x7F, CSI_INTERMEDIATE, A_NONE, CSI_INTERMEDIATE)
          rng.(0x40, 0x7E, CSI_INTERMEDIATE, A_DISPATCH, GROUND)
          rng.(0x30, 0x3F, CSI_INTERMEDIATE, A_NONE, GROUND)

          rng.(0x00, 0x17, CSI_ENTRY, A_EXECUTE, CSI_ENTRY)
          one.(0x19, CSI_ENTRY, A_EXECUTE, CSI_ENTRY)
          rng.(0x1C, 0x1F, CSI_ENTRY, A_EXECUTE, CSI_ENTRY)
          one.(0x7F, CSI_ENTRY, A_NONE, CSI_ENTRY)
          rng.(0x40, 0x7E, CSI_ENTRY, A_DISPATCH, GROUND)
          rng.(0x20, 0x2F, CSI_ENTRY, A_COLLECT, CSI_INTERMEDIATE)
          rng.(0x30, 0x3B, CSI_ENTRY, A_PARAM, CSI_PARAM)
          rng.(0x3C, 0x3F, CSI_ENTRY, A_PREFIX, CSI_PARAM)

          rng.(0x00, 0x06, OSC_STRING, A_NONE, OSC_STRING)
          rng.(0x08, 0x17, OSC_STRING, A_NONE, OSC_STRING)
          one.(0x19, OSC_STRING, A_NONE, OSC_STRING)
          rng.(0x1C, 0x1F, OSC_STRING, A_NONE, OSC_STRING)
          rng.(0x20, 0xFF, OSC_STRING, A_PUT, OSC_STRING)
          one.(0x1B, OSC_STRING, A_DISPATCH, ESCAPE)
          one.(0x07, OSC_STRING, A_DISPATCH, GROUND)
          one.(0x9C, OSC_STRING, A_DISPATCH, GROUND)
          [0x18, 0x1A].each { |c| one.(c, OSC_STRING, A_NONE, GROUND) }

          t.freeze
        end

        # --- uniseg grapheme clusters and widths (grapheme.go, graphemerules.go, width.go) -----------

        PR_ANY = 1
        PR_PREPEND = 2
        PR_CR = 3
        PR_LF = 4
        PR_CONTROL = 5
        PR_EXTEND = 6
        PR_REGIONAL_INDICATOR = 7
        PR_SPACING_MARK = 8
        PR_L = 9
        PR_V = 10
        PR_T = 11
        PR_LV = 12
        PR_LVT = 13
        PR_ZWJ = 14
        PR_EXTENDED_PICTOGRAPHIC = 15

        GR_ANY = 0
        GR_CR = 1
        GR_CONTROL_LF = 2
        GR_L = 3
        GR_LVV = 4
        GR_LVTT = 5
        GR_PREPEND = 6
        GR_EXTENDED_PICTOGRAPHIC = 7
        GR_EXTENDED_PICTOGRAPHIC_ZWJ = 8
        GR_RI_ODD = 9
        GR_RI_EVEN = 10

        RUNE_ERROR = 0xFFFD
        VS15 = 0xFE0E
        VS16 = 0xFE0F

        # grTransitions: [state, prop] => [new state, boundary?, rule number].
        GR_TRANSITIONS = {
          [GR_ANY, PR_CR] => [GR_CR, true, 50],
          [GR_ANY, PR_LF] => [GR_CONTROL_LF, true, 50],
          [GR_ANY, PR_CONTROL] => [GR_CONTROL_LF, true, 50],
          [GR_CR, PR_ANY] => [GR_ANY, true, 40],
          [GR_CONTROL_LF, PR_ANY] => [GR_ANY, true, 40],
          [GR_CR, PR_LF] => [GR_CONTROL_LF, false, 30],
          [GR_ANY, PR_L] => [GR_L, true, 9990],
          [GR_L, PR_L] => [GR_L, false, 60],
          [GR_L, PR_V] => [GR_LVV, false, 60],
          [GR_L, PR_LV] => [GR_LVV, false, 60],
          [GR_L, PR_LVT] => [GR_LVTT, false, 60],
          [GR_ANY, PR_LV] => [GR_LVV, true, 9990],
          [GR_ANY, PR_V] => [GR_LVV, true, 9990],
          [GR_LVV, PR_V] => [GR_LVV, false, 70],
          [GR_LVV, PR_T] => [GR_LVTT, false, 70],
          [GR_ANY, PR_LVT] => [GR_LVTT, true, 9990],
          [GR_ANY, PR_T] => [GR_LVTT, true, 9990],
          [GR_LVTT, PR_T] => [GR_LVTT, false, 80],
          [GR_ANY, PR_EXTEND] => [GR_ANY, false, 90],
          [GR_ANY, PR_ZWJ] => [GR_ANY, false, 90],
          [GR_ANY, PR_SPACING_MARK] => [GR_ANY, false, 91],
          [GR_ANY, PR_PREPEND] => [GR_PREPEND, true, 9990],
          [GR_PREPEND, PR_ANY] => [GR_ANY, false, 92],
          [GR_ANY, PR_EXTENDED_PICTOGRAPHIC] => [GR_EXTENDED_PICTOGRAPHIC, true, 9990],
          [GR_EXTENDED_PICTOGRAPHIC, PR_EXTEND] => [GR_EXTENDED_PICTOGRAPHIC, false, 110],
          [GR_EXTENDED_PICTOGRAPHIC, PR_ZWJ] => [GR_EXTENDED_PICTOGRAPHIC_ZWJ, false, 110],
          [GR_EXTENDED_PICTOGRAPHIC_ZWJ, PR_EXTENDED_PICTOGRAPHIC] => [GR_EXTENDED_PICTOGRAPHIC, false, 110],
          [GR_ANY, PR_REGIONAL_INDICATOR] => [GR_RI_ODD, true, 9990],
          [GR_RI_ODD, PR_REGIONAL_INDICATOR] => [GR_RI_EVEN, false, 120],
          [GR_RI_EVEN, PR_REGIONAL_INDICATOR] => [GR_RI_ODD, true, 120]
        }.freeze

        # transitionGraphemeState depends only on (state, property), so precompute it for every
        # state (-1..10) and property (0..15). Entry: new_state << 1 | boundary.
        GR_STATE_TABLE = begin
          table = Array.new(12 * 16)
          (-1..GR_RI_EVEN).each do |state|
            (0..PR_EXTENDED_PICTOGRAPHIC).each do |prop|
              new_state, boundary =
                if (hit = GR_TRANSITIONS[[state, prop]])
                  [hit[0], hit[1]]
                else
                  any_prop = GR_TRANSITIONS[[state, PR_ANY]]
                  any_state = GR_TRANSITIONS[[GR_ANY, prop]]
                  if any_prop && any_state
                    b = any_state[1]
                    b = any_prop[1] if any_prop[2] < any_state[2]
                    [any_state[0], b]
                  elsif any_prop
                    [any_prop[0], any_prop[1]]
                  elsif any_state
                    [any_state[0], any_state[1]]
                  else
                    [GR_ANY, true]
                  end
                end
              table[((state + 1) << 4) | prop] = (new_state << 1) | (boundary ? 1 : 0)
            end
          end
          table.freeze
        end

        GRAPHEME_TABLE = Tables::GRAPHEME
        GRAPHEME_COUNT = GRAPHEME_TABLE.size / 3
        WIDE_TABLE = Tables::WIDE
        WIDE_COUNT = WIDE_TABLE.size / 2
        EMOJI_TABLE = Tables::EMOJI_PRESENTATION
        EMOJI_COUNT = EMOJI_TABLE.size / 2

        # Memoized per-code-point lookups (the binary searches dominate width measurement).
        PROPERTY_CACHE = {}
        EAW_WIDTH_CACHE = {}
        EMOJI_WIDTH_CACHE = {}

        # Go's unicode.IsSpace above Latin-1 (the White_Space property).
        SPACE_ABOVE_LATIN1 = [0x1680, *0x2000..0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000].freeze

        NBSP = 0xA0
        ESC = 0x1B
        BEL = 0x07
        CAN = 0x18
        SUB = 0x1A
        US = 0x1F
        DEL = 0x7F
        DCS = 0x90
        SOS = 0x98
        CSI = 0x9B
        ST = 0x9C
        OSC = 0x9D
        PM = 0x9E
        APC = 0x9F

        RESET_STYLE = "\e[m"

        # Bytes that can move the parser out of the ground state or start a UTF-8 sequence.
        SPECIAL_BYTE = Regexp.new("[\\x1b\\x80-\\xff]".b, Regexp::NOENCODING)

        extend self

        # ansi.StringWidth: the number of terminal cells s occupies. ANSI escape sequences are
        # ignored; text is measured per grapheme cluster with uniseg widths.
        def string_width(s)
          return 0 if s.empty?
          return s.count(" -~") if s.ascii_only? && !s.include?("\e")

          b = s.b
          n = b.bytesize
          pstate = GROUND
          width = 0
          i = 0
          while i < n
            if pstate == GROUND
              # Fast path: in the ground state every byte below 0x80 other than ESC is printed (width 1)
              # or executed (width 0) and leaves the parser in the ground state.
              j = b.index(SPECIAL_BYTE, i) || n
              if j > i
                width += b.byteslice(i, j - i).count(" -~")
                i = j
                next
              end
            end
            v = TABLE[(pstate << 8) | b.getbyte(i)]
            state = v & 15
            if state == UTF8
              len, w, = cluster_at(b, i, -1)
              width += w
              i += len
              pstate = GROUND
              next
            end
            width += 1 if (v >> 4) == A_PRINT
            pstate = state
            i += 1
          end
          width
        end

        # ansi.Strip: removes ANSI escape sequences, keeping printable text and control characters.
        def strip(s)
          return s.dup if s.ascii_only? && !s.include?("\e")

          b = s.b
          buf = String.new(capacity: b.bytesize, encoding: Encoding::BINARY)
          ri = 0
          rw = 0
          pstate = GROUND
          b.each_byte do |c|
            if pstate == UTF8
              buf << c
              ri += 1
              next if ri < rw

              pstate = GROUND
              ri = 0
              rw = 0
              next
            end

            v = TABLE[(pstate << 8) | c]
            state = v & 15
            case v >> 4
            when A_COLLECT
              if state == UTF8
                rw = utf8_byte_len(c)
                buf << c
                ri += 1
              end
            when A_PRINT, A_EXECUTE
              buf << c
            end
            pstate = state
          end
          buf.force_encoding(Encoding::UTF_8)
        end

        # ansi.Truncate: cuts s to `length` cells, appending `tail` when it was cut. Escape sequences
        # after the cut are kept.
        def truncate(s, length, tail = "")
          return s if string_width(s) <= length

          tail_b = tail.b
          length -= string_width(tail)
          return +"" if length.negative?

          b = s.b
          n = b.bytesize
          buf = String.new(capacity: n, encoding: Encoding::BINARY)
          cur_width = 0
          ignoring = false
          pstate = GROUND
          i = 0
          while i < n
            c = b.getbyte(i)
            v = TABLE[(pstate << 8) | c]
            state = v & 15
            if state == UTF8
              len, width, = cluster_at(b, i, -1)
              start = i
              i += len
              next if ignoring

              if cur_width + width > length
                ignoring = true
                buf << tail_b
                next
              end

              cur_width += width
              buf << b.byteslice(start, len)
              pstate = GROUND
              next
            end

            if (v >> 4) == A_PRINT
              if cur_width >= length && !ignoring
                ignoring = true
                buf << tail_b
              end
              if ignoring
                i += 1
                next
              end
              cur_width += 1
            end
            buf << c
            i += 1

            pstate = state
            if cur_width > length && !ignoring
              ignoring = true
              buf << tail_b
            end
          end
          buf.force_encoding(Encoding::UTF_8)
        end

        # ansi.TruncateLeft: removes the first n cells of s, prepending `prefix` when anything was cut.
        def truncate_left(s, n, prefix = "")
          return s if n <= 0

          prefix_b = prefix.b
          b = s.b
          size = b.bytesize
          buf = String.new(capacity: size, encoding: Encoding::BINARY)
          cur_width = 0
          ignoring = true
          pstate = GROUND
          i = 0
          while i < size
            unless ignoring
              buf << b.byteslice(i, size - i)
              break
            end

            c = b.getbyte(i)
            v = TABLE[(pstate << 8) | c]
            state = v & 15
            if state == UTF8
              len, width, = cluster_at(b, i, -1)
              start = i
              i += len
              cur_width += width
              if cur_width > n && ignoring
                ignoring = false
                buf << prefix_b
              end
              next if ignoring

              buf << b.byteslice(start, len) if cur_width > n
              pstate = GROUND
              next
            end

            if (v >> 4) == A_PRINT
              cur_width += 1
              if cur_width > n && ignoring
                ignoring = false
                buf << prefix_b
              end
              if ignoring
                i += 1
                next
              end
            end
            buf << c
            i += 1

            pstate = state
            if cur_width > n && ignoring
              ignoring = false
              buf << prefix_b
            end
          end
          buf.force_encoding(Encoding::UTF_8)
        end

        # ansi.Cut: the cells in [left, right) of s, keeping escape sequences intact.
        def cut(s, left, right)
          return +"" if right <= left
          return truncate(s, right, "") if left.zero?

          truncate_left(truncate(s, right, ""), left, "")
        end

        # ansi.Hardwrap: wraps at `limit` cells, breaking anywhere.
        def hardwrap(s, limit, preserve_space)
          return s if limit < 1

          b = s.b
          n = b.bytesize
          buf = String.new(capacity: n + (n / limit) + 1, encoding: Encoding::BINARY)
          cur_width = 0
          force_newline = false
          pstate = GROUND
          i = 0
          while i < n
            c = b.getbyte(i)
            v = TABLE[(pstate << 8) | c]
            state = v & 15
            action = v >> 4
            if state == UTF8
              len, width, = cluster_at(b, i, -1)
              start = i
              i += len
              if cur_width + width > limit
                buf << 0x0A
                cur_width = 0
              end
              if !preserve_space && cur_width.zero? && len <= 4
                r, = decode_rune(b, start, start + len)
                if r != RUNE_ERROR && space?(r)
                  pstate = GROUND
                  next
                end
              end
              buf << b.byteslice(start, len)
              cur_width += width
              pstate = GROUND
              next
            end

            if action == A_PRINT || action == A_EXECUTE
              if c == 0x0A
                buf << 0x0A
                cur_width = 0
                force_newline = false
              else
                if cur_width + 1 > limit
                  buf << 0x0A
                  cur_width = 0
                  force_newline = true
                end
                skip = false
                if cur_width.zero?
                  if !preserve_space && force_newline && space?(c)
                    skip = true
                  else
                    force_newline = false
                  end
                end
                unless skip
                  buf << c
                  cur_width += 1 if action == A_PRINT
                end
              end
            else
              buf << c
            end

            pstate = state
            i += 1
          end
          buf.force_encoding(Encoding::UTF_8)
        end

        # ansi.Wordwrap: wraps at `limit` cells on word boundaries only (long words overflow).
        # A hyphen and every rune in `breakpoints` are breakpoints.
        def wordwrap(s, limit, breakpoints = "")
          return s if limit < 1

          bp_runes = breakpoint_runes(breakpoints)
          bp_bytes = bp_runes.map { |r| [r].pack("U").b }
          b = s.b
          n = b.bytesize
          buf = String.new(capacity: n + 16, encoding: Encoding::BINARY)
          word = String.new(encoding: Encoding::BINARY)
          space = String.new(encoding: Encoding::BINARY)
          cur_width = 0
          word_len = 0
          pstate = GROUND

          add_space = lambda do
            cur_width += space.bytesize
            buf << space
            space.clear
          end
          add_word = lambda do
            next if word.empty?

            add_space.call
            cur_width += word_len
            buf << word
            word.clear
            word_len = 0
          end
          add_newline = lambda do
            buf << 0x0A
            cur_width = 0
            space.clear
          end

          i = 0
          while i < n
            c = b.getbyte(i)
            v = TABLE[(pstate << 8) | c]
            state = v & 15
            action = v >> 4
            if state == UTF8
              len, width, = cluster_at(b, i, -1)
              cluster = b.byteslice(i, len)
              i += len
              r, = decode_rune(cluster, 0, len)
              if r != RUNE_ERROR && space?(r) && r != NBSP
                add_word.call
                append_rune(space, r)
              elsif bp_bytes.any? { |bp| cluster.include?(bp) }
                add_space.call
                add_word.call
                buf << cluster
                cur_width += 1
              else
                word << cluster
                word_len += width
                add_newline.call if cur_width + space.bytesize + word_len > limit && word_len < limit
              end
              pstate = GROUND
              next
            end

            if action == A_PRINT || action == A_EXECUTE
              if c == 0x0A
                if word_len.zero?
                  if cur_width + space.bytesize > limit
                    cur_width = 0
                  else
                    buf << space
                  end
                  space.clear
                end
                add_word.call
                add_newline.call
              elsif space?(c)
                add_word.call
                space << c
              elsif c == 0x2D || bp_runes.include?(c)
                add_space.call
                add_word.call
                buf << c
                cur_width += 1
              else
                word << c
                word_len += 1
                add_newline.call if cur_width + space.bytesize + word_len > limit && word_len < limit
              end
            else
              word << c
            end

            pstate = state
            i += 1
          end

          add_word.call
          buf.force_encoding(Encoding::UTF_8)
        end

        # ansi.Wrap: wraps at `limit` cells on word boundaries, breaking words longer than the limit.
        # A hyphen and every rune in `breakpoints` are breakpoints. Used by lipgloss's table resizing.
        def wrap(s, limit, breakpoints = "")
          return s if limit < 1

          bp_runes = breakpoint_runes(breakpoints)
          bp_bytes = bp_runes.map { |r| [r].pack("U").b }
          b = s.b
          n = b.bytesize
          buf = String.new(capacity: n + 16, encoding: Encoding::BINARY)
          word = String.new(encoding: Encoding::BINARY)
          space = String.new(encoding: Encoding::BINARY)
          cur_width = 0
          word_len = 0
          pstate = GROUND

          add_space = lambda do
            cur_width += space.bytesize
            buf << space
            space.clear
          end
          add_word = lambda do
            next if word.empty?

            add_space.call
            cur_width += word_len
            buf << word
            word.clear
            word_len = 0
          end
          add_newline = lambda do
            buf << 0x0A
            cur_width = 0
            space.clear
          end

          i = 0
          while i < n
            c = b.getbyte(i)
            v = TABLE[(pstate << 8) | c]
            state = v & 15
            action = v >> 4
            if state == UTF8
              len, width, = cluster_at(b, i, -1)
              cluster = b.byteslice(i, len)
              i += len
              r, = decode_rune(cluster, 0, len)
              if r != RUNE_ERROR && space?(r) && r != NBSP
                add_word.call
                append_rune(space, r)
              elsif bp_bytes.any? { |bp| cluster.include?(bp) }
                add_space.call
                if cur_width + word_len + width > limit
                  word << cluster
                  word_len += width
                else
                  add_word.call
                  buf << cluster
                  cur_width += width
                end
              else
                add_word.call if word_len + width > limit
                word << cluster
                word_len += width
                add_newline.call if cur_width + word_len + space.bytesize > limit
              end
              pstate = GROUND
              next
            end

            if action == A_PRINT || action == A_EXECUTE
              if c == 0x0A
                if word_len.zero?
                  if cur_width + space.bytesize > limit
                    cur_width = 0
                  else
                    buf << space
                  end
                  space.clear
                end
                add_word.call
                add_newline.call
              elsif space?(c)
                add_word.call
                append_rune(space, c)
              elsif c == 0x2D || bp_runes.include?(c)
                add_space.call
                if cur_width + word_len >= limit
                  append_rune(word, c)
                  word_len += 1
                else
                  add_word.call
                  append_rune(buf, c)
                  cur_width += 1
                end
              else
                add_newline.call if cur_width == limit
                append_rune(word, c)
                word_len += 1
                add_word.call if word_len == limit
                add_newline.call if cur_width + word_len + space.bytesize > limit
              end
            else
              word << c
            end

            pstate = state
            i += 1
          end

          if word_len.zero?
            if cur_width + space.bytesize > limit
              cur_width = 0
            else
              buf << space
            end
            space.clear
          end
          add_word.call
          buf.force_encoding(Encoding::UTF_8)
        end

        # cellbuf.Wrap: like ansi.Wrap, but tracks the active SGR style and OSC 8 hyperlink and
        # closes/reopens them around every inserted line break. Used by lipgloss Style#Render.
        def cellbuf_wrap(s, limit, breakpoints = "")
          return +"" if s.empty?
          return s if limit < 1

          bp_runes = breakpoint_runes(breakpoints)
          p = SeqParser.new
          b = s.b
          n = b.bytesize
          buf = String.new(capacity: n + 16, encoding: Encoding::BINARY)
          word = String.new(encoding: Encoding::BINARY)
          space = String.new(encoding: Encoding::BINARY)
          style = CellStyle.new
          cur_style = CellStyle.new
          link = [+"", +""] # [url, params]
          cur_link = ["", ""]
          cur_width = 0
          word_len = 0

          add_space = lambda do
            cur_width += space.bytesize
            buf << space
            space.clear
          end
          add_word = lambda do
            next if word.empty?

            cur_link = link.dup
            cur_style = style.dup
            add_space.call
            cur_width += word_len
            buf << word
            word.clear
            word_len = 0
          end
          add_newline = lambda do
            link_set = !(cur_link[0].empty? && cur_link[1].empty?)
            buf << RESET_STYLE unless cur_style.empty?
            buf << "\e]8;;\a" if link_set
            buf << 0x0A
            buf << "\e]8;" << cur_link[1].b << ";" << cur_link[0].b << "\a" if link_set
            buf << cur_style.sequence unless cur_style.empty?
            cur_width = 0
            space.clear
          end

          i = 0
          state = 0
          while i < n
            len, width, state = decode_sequence(b, i, state, p)
            seq = b.byteslice(i, len)
            if width.zero?
              if seq == "\t"
                add_word.call
                space << seq
              elsif seq == "\n"
                if word_len.zero?
                  if cur_width + space.bytesize > limit
                    cur_width = 0
                  else
                    buf << space
                  end
                  space.clear
                end
                add_word.call
                add_newline.call
              else
                f = seq.getbyte(0)
                s1 = seq.getbyte(1)
                if (f == CSI || (f == ESC && s1 == 0x5B)) && p.cmd == 0x6D
                  read_style(p.params_slice, style)
                elsif (f == OSC || (f == ESC && s1 == 0x5D)) && p.cmd == 8
                  read_link(p.data, link)
                end
                word << seq
              end
            else
              handled = false
              if len == 1
                r = seq.getbyte(0)
                r = RUNE_ERROR if r >= 0x80 # a lone invalid UTF-8 byte decodes to RuneError
                if space?(r)
                  add_word.call
                  append_rune(space, r)
                  handled = true
                elsif r == 0x2D || bp_runes.include?(r)
                  add_space.call
                  if cur_width + word_len + width <= limit
                    add_word.call
                    buf << seq
                    cur_width += width
                    handled = true
                  end
                end
              end

              unless handled
                add_word.call if word_len + width > limit
                word << seq
                word_len += width
                add_newline.call if cur_width + word_len + space.bytesize > limit
              end
            end
            i += len
          end

          if word_len.zero?
            if cur_width + space.bytesize > limit
              cur_width = 0
            else
              buf << space
            end
            space.clear
          end
          add_word.call

          buf << "\e]8;;\a" unless cur_link[0].empty? && cur_link[1].empty?
          buf << RESET_STYLE unless cur_style.empty?
          buf.force_encoding(Encoding::UTF_8)
        end

        # uniseg.FirstGraphemeClusterInString with a fresh state: [cluster, width].
        def first_grapheme_cluster(s)
          cluster, _rest, width, = first_grapheme_cluster_in_string(s, -1)
          [cluster, width]
        end

        # uniseg.FirstGraphemeClusterInString(str, state) -> [cluster, rest, width, new_state].
        # Pass -1 as the state for the first call and the returned state for the following ones.
        def first_grapheme_cluster_in_string(s, state = -1)
          return ["", "", 0, 0] if s.empty?

          b = s.b
          len, width, new_state = cluster_at(b, 0, state)
          cluster = b.byteslice(0, len).force_encoding(Encoding::UTF_8)
          rest = b.byteslice(len, b.bytesize - len).force_encoding(Encoding::UTF_8)
          [cluster, rest, width, new_state]
        end

        # --- internals ----------------------------------------------------------------------------

        # uniseg.FirstGraphemeCluster on the bytes of `b` (a binary string) starting at `i`.
        # Returns [byte length, width, new state].
        def cluster_at(b, i, state)
          n = b.bytesize
          r, length = decode_rune(b, i, n)
          if n - i <= length
            prop = state.negative? ? grapheme_property(r) : state >> 4
            return [n - i, rune_width(r, prop), GR_ANY | (prop << 4)]
          end

          if state.negative?
            first_prop = grapheme_property(r)
            state = GR_STATE_TABLE[first_prop] >> 1 # row for state -1
          else
            first_prop = state >> 4
          end
          width = rune_width(r, first_prop)

          loop do
            r, l = decode_rune(b, i + length, n)
            prop = grapheme_property(r)
            t = GR_STATE_TABLE[(((state & 0xF) + 1) << 4) | prop]
            state = t >> 1
            return [length, width, state | (prop << 4)] if t.odd?

            if first_prop == PR_EXTENDED_PICTOGRAPHIC
              if r == VS15
                width = 1
              elsif r == VS16
                width = 2
              end
            elsif first_prop != PR_REGIONAL_INDICATOR && first_prop != PR_L
              width += rune_width(r, prop)
            end

            length += l
            return [n - i, width, GR_ANY | (prop << 4)] if n - i <= length
          end
        end

        # utf8.DecodeRune on b[i...n]: [rune, size]; invalid input yields [RUNE_ERROR, 1].
        def decode_rune(b, i, n)
          c0 = b.getbyte(i)
          return [c0, 1] if c0 < 0x80
          return [RUNE_ERROR, 1] if c0 < 0xC2 || c0 > 0xF4

          avail = n - i
          return [RUNE_ERROR, 1] if avail < 2

          c1 = b.getbyte(i + 1)
          lo = 0x80
          hi = 0xBF
          if c0 == 0xE0
            lo = 0xA0
          elsif c0 == 0xED
            hi = 0x9F
          elsif c0 == 0xF0
            lo = 0x90
          elsif c0 == 0xF4
            hi = 0x8F
          end
          return [RUNE_ERROR, 1] if c1 < lo || c1 > hi
          return [((c0 & 0x1F) << 6) | (c1 & 0x3F), 2] if c0 < 0xE0
          return [RUNE_ERROR, 1] if avail < 3

          c2 = b.getbyte(i + 2)
          return [RUNE_ERROR, 1] if c2 < 0x80 || c2 > 0xBF
          return [((c0 & 0x0F) << 12) | ((c1 & 0x3F) << 6) | (c2 & 0x3F), 3] if c0 < 0xF0
          return [RUNE_ERROR, 1] if avail < 4

          c3 = b.getbyte(i + 3)
          return [RUNE_ERROR, 1] if c3 < 0x80 || c3 > 0xBF

          [((c0 & 0x07) << 18) | ((c1 & 0x3F) << 12) | ((c2 & 0x3F) << 6) | (c3 & 0x3F), 4]
        end

        def grapheme_property(r)
          return PR_ANY if r >= 0x20 && r <= 0x7E
          return PR_LF if r == 0x0A
          return PR_CR if r == 0x0D
          return PR_CONTROL if r <= 0x1F || r == 0x7F

          PROPERTY_CACHE[r] ||= search_grapheme_property(r)
        end

        def search_grapheme_property(r)
          lo = 0
          hi = GRAPHEME_COUNT
          t = GRAPHEME_TABLE
          while hi > lo
            mid = (lo + hi) >> 1
            base = mid * 3
            if r < t[base]
              hi = mid
            elsif r > t[base + 1]
              lo = mid + 1
            else
              return t[base + 2]
            end
          end
          0
        end

        def in_ranges?(t, count, r)
          lo = 0
          hi = count
          while hi > lo
            mid = (lo + hi) >> 1
            base = mid << 1
            if r < t[base]
              hi = mid
            elsif r > t[base + 1]
              lo = mid + 1
            else
              return true
            end
          end
          false
        end

        # uniseg runeWidth (EastAsianAmbiguousWidth = 1).
        def rune_width(r, prop)
          case prop
          when PR_CONTROL, PR_CR, PR_LF, PR_EXTEND, PR_ZWJ
            return 0
          when PR_REGIONAL_INDICATOR
            return 2
          when PR_EXTENDED_PICTOGRAPHIC
            return EMOJI_WIDTH_CACHE[r] ||= in_ranges?(EMOJI_TABLE, EMOJI_COUNT, r) ? 2 : 1
          end
          return 1 if r < 0x1100 # nothing below U+1100 is East Asian Wide or Fullwidth

          EAW_WIDTH_CACHE[r] ||=
            if r == 0x2E3A then 3
            elsif r == 0x2E3B then 4
            else in_ranges?(WIDE_TABLE, WIDE_COUNT, r) ? 2 : 1
            end
        end

        # Go's unicode.IsSpace.
        def space?(r)
          if r <= 0xFF
            r == 0x20 || (r >= 0x09 && r <= 0x0D) || r == 0x85 || r == 0xA0
          else
            SPACE_ABOVE_LATIN1.include?(r)
          end
        end

        def utf8_byte_len(c)
          if c <= 0x7F then 1
          elsif c >= 0xC0 && c <= 0xDF then 2
          elsif c >= 0xE0 && c <= 0xEF then 3
          elsif c >= 0xF0 && c <= 0xF7 then 4
          else -1
          end
        end

        # bytes.Buffer#WriteRune into a binary buffer.
        def append_rune(buf, r)
          if r < 0x80
            buf << r
          else
            buf << [r].pack("U").b
          end
        end

        # The runes of a Go string (invalid bytes become U+FFFD).
        def breakpoint_runes(breakpoints)
          return [] if breakpoints.nil? || breakpoints.empty?

          breakpoints.b.force_encoding(Encoding::UTF_8).scrub("�").codepoints
        end

        # Parser state collected by ansi.DecodeSequence (the parts cellbuf.Wrap reads).
        class SeqParser
          MAX_PARAMS = 32
          MAX_DATA = 4 * 1024 * 1024
          MISSING_PARAM = 0x7FFFFFFF
          HAS_MORE_FLAG = -0x80000000
          MISSING_COMMAND = MISSING_PARAM

          attr_accessor :cmd, :params, :params_len, :data

          def initialize
            @params = Array.new(MAX_PARAMS, 0)
            @params_len = 0
            @data = String.new(encoding: Encoding::BINARY)
            @cmd = 0
          end

          def params_slice
            @params[0, @params_len]
          end
        end

        # ansi.DecodeSequence on b starting at i: [byte length, width, new state].
        def decode_sequence(b, i, state, p)
          n = b.bytesize
          j = i
          while j < n
            c = b.getbyte(j)
            case state
            when 0 # NormalState
              case c
              when ESC
                p.params[0] = SeqParser::MISSING_PARAM
                p.cmd = 0
                p.params_len = 0
                p.data.clear
                state = 4
                j += 1
                next
              when CSI, DCS
                p.params[0] = SeqParser::MISSING_PARAM
                p.cmd = 0
                p.params_len = 0
                p.data.clear
                state = 1
                j += 1
                next
              when OSC, APC, SOS, PM
                p.cmd = SeqParser::MISSING_COMMAND
                p.data.clear
                state = 5
                j += 1
                next
              end

              p.data.clear
              p.params_len = 0
              p.cmd = 0
              return [1, 1, 0] if c > US && c < DEL
              return [1, 0, 0] if c <= US || c == DEL || c < 0xC0

              len, width, = cluster_at(b, i, -1)
              return [len, width, 0]
            when 1, 2, 3 # Prefix, Params, Intermed (with Go's fallthrough)
              if state == 1
                if c >= 0x3C && c <= 0x3F
                  p.cmd = (p.cmd & ~(0xFF << 8)) | (c << 8)
                  j += 1
                  next
                end
                state = 2
              end
              if state == 2
                if c >= 0x30 && c <= 0x39
                  pl = p.params_len
                  cur = p.params[pl]
                  cur = 0 if cur.nil? || cur == SeqParser::MISSING_PARAM
                  p.params[pl] = (cur * 10) + (c - 0x30)
                  j += 1
                  next
                end
                if c == 0x3A
                  p.params[p.params_len] = (p.params[p.params_len] || SeqParser::MISSING_PARAM) | SeqParser::HAS_MORE_FLAG
                end
                if c == 0x3B || c == 0x3A
                  p.params_len += 1
                  p.params[p.params_len] = SeqParser::MISSING_PARAM if p.params_len < SeqParser::MAX_PARAMS
                  j += 1
                  next
                end
                state = 3
              end
              if c >= 0x20 && c <= 0x2F
                p.cmd = (p.cmd & ~(0xFF << 16)) | (c << 16)
                j += 1
                next
              end

              pl = p.params_len
              if (pl.positive? && pl < SeqParser::MAX_PARAMS - 1) ||
                 (pl.zero? && p.params[0] != SeqParser::MISSING_PARAM)
                p.params_len += 1
              end

              if c >= 0x40 && c <= 0x7E
                p.cmd = (p.cmd & ~0xFF) | c
                f = b.getbyte(i)
                if f == DCS || (f == ESC && b.getbyte(i + 1) == 0x50)
                  p.data.clear
                  state = 5
                  j += 1
                  next
                end
                return [j + 1 - i, 0, 0]
              end
              return [j - i, 0, 0]
            when 4 # EscapeState
              case c
              when 0x5B, 0x50
                p.params[0] = SeqParser::MISSING_PARAM
                p.params_len = 0
                p.cmd = 0
                state = 1
                j += 1
                next
              when 0x5D, 0x58, 0x5E, 0x5F
                p.cmd = SeqParser::MISSING_COMMAND
                p.data.clear
                state = 5
                j += 1
                next
              end

              if c >= 0x20 && c <= 0x2F
                p.cmd = (p.cmd & ~(0xFF << 16)) | (c << 16)
                j += 1
                next
              elsif c >= 0x30 && c <= 0x7E
                p.cmd = (p.cmd & ~0xFF) | c
                return [j + 1 - i, 0, 0]
              end
              return [j - i, 0, 0]
            when 5 # StringState
              osc = osc_prefix?(b, i)
              case c
              when BEL
                if osc
                  parse_osc_cmd(p)
                  return [j + 1 - i, 0, 0]
                end
              when CAN, SUB
                parse_osc_cmd(p) if osc
                return [j - i, 0, 0]
              when ST
                parse_osc_cmd(p) if osc
                return [j + 1 - i, 0, 0]
              when ESC
                if b.getbyte(j + 1) == 0x5C
                  parse_osc_cmd(p) if osc
                  return [j + 2 - i, 0, 0]
                end
                return [j - i, 0, 0]
              end

              if p.data.bytesize < SeqParser::MAX_DATA
                p.data << c
                parse_osc_cmd(p) if c == 0x3B && osc
              end
            end
            j += 1
          end
          [n - i, 0, state]
        end

        def osc_prefix?(b, i)
          f = b.getbyte(i)
          f == OSC || (f == ESC && b.getbyte(i + 1) == 0x5D)
        end

        def parse_osc_cmd(p)
          return unless p.cmd == SeqParser::MISSING_COMMAND

          p.data.each_byte do |d|
            break if d < 0x30 || d > 0x39

            p.cmd = 0 if p.cmd == SeqParser::MISSING_COMMAND
            p.cmd = (p.cmd * 10) + (d - 0x30)
          end
        end

        # cellbuf.Style: SGR state. Colors are [:basic, n], [:ext, n], [:rgb, r, g, b] (any
        # color.Color, already reduced to 8-bit channels by ansi's shift) or nil.
        class CellStyle
          BOLD = 1
          FAINT = 2
          ITALIC = 4
          SLOW_BLINK = 8
          RAPID_BLINK = 16
          REVERSE = 32
          CONCEAL = 64
          STRIKETHROUGH = 128
          ATTR_CODES = [[BOLD, "1"], [FAINT, "2"], [ITALIC, "3"], [SLOW_BLINK, "5"], [RAPID_BLINK, "6"],
                        [REVERSE, "7"], [CONCEAL, "8"], [STRIKETHROUGH, "9"]].freeze
          UNDERLINE_CODES = [nil, "4", "4:2", "4:3", "4:4", "4:5"].freeze

          attr_accessor :fg, :bg, :ul, :attrs, :ul_style

          def initialize
            reset
          end

          def reset
            @fg = nil
            @bg = nil
            @ul = nil
            @attrs = 0
            @ul_style = 0
          end

          def set_attr(mask, on)
            @attrs = on ? (@attrs | mask) : (@attrs & ~mask)
          end

          def empty?
            @fg.nil? && @bg.nil? && @ul.nil? && @attrs.zero? && @ul_style.zero?
          end

          def sequence
            return RESET_STYLE if empty?

            parts = []
            ATTR_CODES.each { |mask, code| parts << code if @attrs & mask != 0 }
            parts << UNDERLINE_CODES[@ul_style] if @ul_style != 0
            parts << color_string(@fg, 30, 90, "38") if @fg
            parts << color_string(@bg, 40, 100, "48") if @bg
            parts << underline_color_string(@ul) if @ul
            "\e[#{parts.join(';')}m"
          end

          private

          def color_string(color, base, bright_base, ext)
            case color[0]
            when :basic
              n = color[1]
              n < 8 ? (base + n).to_s : (bright_base + n - 8).to_s
            when :ext then "#{ext};5;#{color[1]}"
            else "#{ext};2;#{color[1]};#{color[2]};#{color[3]}"
            end
          end

          def underline_color_string(color)
            case color[0]
            when :basic, :ext then "58;5;#{color[1]}"
            else "58;2;#{color[1]};#{color[2]};#{color[3]}"
            end
          end
        end

        PARAM_MASK = 0x7FFFFFFF

        def param_value(raw, default)
          return default if raw.nil?

          v = raw & PARAM_MASK
          v == SeqParser::MISSING_PARAM ? default : v
        end

        def param_more?(raw)
          !raw.nil? && (raw & SeqParser::HAS_MORE_FLAG) != 0
        end

        # cellbuf.ReadStyle.
        def read_style(params, pen)
          if params.empty?
            pen.reset
            return
          end

          i = 0
          while i < params.size
            param = param_value(params[i], 0)
            has_more = param_more?(params[i])
            case param
            when 0 then pen.reset
            when 1 then pen.set_attr(CellStyle::BOLD, true)
            when 2 then pen.set_attr(CellStyle::FAINT, true)
            when 3 then pen.set_attr(CellStyle::ITALIC, true)
            when 4
              ok = i + 1 < params.size
              next_param = ok ? param_value(params[i + 1], 0) : 0
              if has_more && ok
                if next_param.between?(0, 5)
                  i += 1
                  pen.ul_style = next_param
                end
              else
                pen.ul_style = 1
              end
            when 5 then pen.set_attr(CellStyle::SLOW_BLINK, true)
            when 6 then pen.set_attr(CellStyle::RAPID_BLINK, true)
            when 7 then pen.set_attr(CellStyle::REVERSE, true)
            when 8 then pen.set_attr(CellStyle::CONCEAL, true)
            when 9 then pen.set_attr(CellStyle::STRIKETHROUGH, true)
            when 22
              pen.set_attr(CellStyle::BOLD, false)
              pen.set_attr(CellStyle::FAINT, false)
            when 23 then pen.set_attr(CellStyle::ITALIC, false)
            when 24 then pen.ul_style = 0
            when 25
              pen.set_attr(CellStyle::SLOW_BLINK, false)
              pen.set_attr(CellStyle::RAPID_BLINK, false)
            when 27 then pen.set_attr(CellStyle::REVERSE, false)
            when 28 then pen.set_attr(CellStyle::CONCEAL, false)
            when 29 then pen.set_attr(CellStyle::STRIKETHROUGH, false)
            when 30..37 then pen.fg = [:basic, param - 30]
            when 38, 48, 58
              n, color = read_style_color(params[i..])
              if n.positive?
                case param
                when 38 then pen.fg = color
                when 48 then pen.bg = color
                else pen.ul = color
                end
                i += n - 1
              end
            when 39 then pen.fg = nil
            when 40..47 then pen.bg = [:basic, param - 40]
            when 49 then pen.bg = nil
            when 59 then pen.ul = nil
            when 90..97 then pen.fg = [:basic, param - 90 + 8]
            when 100..107 then pen.bg = [:basic, param - 100 + 8]
            end
            i += 1
          end
        end

        # ansi.ReadStyleColor: [params consumed, color or nil].
        def read_style_color(params)
          return [0, nil] if params.size < 2

          s_more = param_more?(params[0])
          p_more = param_more?(params[1])
          color_type = param_value(params[1], 0)
          n = 2
          more = ->(k) { param_more?(params[k]) }
          val = ->(k) { param_value(params[k], 0) }

          channels = lambda do
            if s_more && p_more && params.size > 8 && more.(2) && more.(3) && more.(4) && more.(5) && more.(6) && more.(7)
              n += 7
              [val.(3), val.(4), val.(5), val.(6)]
            elsif s_more && p_more && params.size > 7 && more.(2) && more.(3) && more.(4) && more.(5) && more.(6)
              n += 6
              [val.(3), val.(4), val.(5), val.(6)]
            elsif s_more && p_more && params.size > 6 && more.(2) && more.(3) && more.(4) && more.(5)
              n += 5
              [val.(3), val.(4), val.(5), val.(6)]
            elsif s_more && p_more && params.size > 5 && more.(2) && more.(3) && more.(4) && !more.(5)
              n += 4
              [val.(3), val.(4), val.(5), -1]
            elsif (s_more && p_more && val.(1) == 2 && more.(2) && more.(3) && !more.(4)) ||
                  (!s_more && !p_more && val.(1) == 2 && !more.(2) && !more.(3) && !more.(4))
              n += 3
              [val.(2), val.(3), val.(4), -1]
            else
              [-1, -1, -1, -1]
            end
          end

          case color_type
          when 0 then [2, nil]
          when 1 then [2, [:rgb, 0, 0, 0]] # color.Transparent
          when 2, 6
            return [0, nil] if params.size < (color_type == 2 ? 5 : 6)

            r, g, b, a = channels.call
            return [0, nil] if r == -1 || g == -1 || b == -1 || (color_type == 6 && a == -1)

            [n, [:rgb, r & 0xFF, g & 0xFF, b & 0xFF]]
          when 3, 4
            return [0, nil] if params.size < (color_type == 3 ? 5 : 6)

            c, m, y, k = channels.call
            return [0, nil] if c == -1 || m == -1 || y == -1 || (color_type == 4 && k == -1)

            k = color_type == 3 ? 0 : k & 0xFF
            [n, cmyk_to_rgb(c & 0xFF, m & 0xFF, y & 0xFF, k)]
          when 5
            return [0, nil] if params.size < 3
            return [0, nil] unless (s_more && p_more && !more.(2)) || (!s_more && !p_more && !more.(2))

            [3, [:ext, val.(2) & 0xFF]]
          else
            [0, nil]
          end
        end

        # color.CMYK#RGBA followed by ansi's shift.
        def cmyk_to_rgb(c, m, y, k)
          w = 0xFFFF - (k * 0x101)
          [:rgb, *[c, m, y].map do |v|
            x = (0xFFFF - (v * 0x101)) * w / 0xFFFF
            x > 0xFF ? x >> 8 : x
          end]
        end

        # cellbuf.ReadLink: OSC 8 data "8;params;url".
        def read_link(data, link)
          parts = data.split(";", -1)
          parts = [""] if parts.empty?
          return unless parts.size == 3

          link[1] = parts[1]
          link[0] = parts[2]
        end
      end
    end
  end
end
