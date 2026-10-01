# frozen_string_literal: true

require_relative "width_table"

module R2UI
  module Compat
    module Tea
      # Ports of charmbracelet/x/ansi v0.8.0 StringWidth and Truncate, which
      # the bubbletea 0.1.4 gem's renderer uses. Escape sequences are found
      # with the same DEC ANSI transition table; text is measured per
      # grapheme cluster the way rivo/uniseg v0.4.7 measures it.
      module ANSI
        # Parser states (x/ansi/parser/const.go).
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

        # Parser actions.
        NONE = 0
        CLEAR = 1
        COLLECT = 2
        PREFIX = 3
        DISPATCH = 4
        EXECUTE = 5
        START = 6
        PUT = 7
        PARAM = 8
        PRINT = 9
        IGNORE = NONE

        CURSOR_HOME_POSITION = "\e[H"
        ERASE_ENTIRE_SCREEN = "\e[2J"

        VS15 = 0xFE0E
        VS16 = 0xFE0F

        # x/ansi parser.GenerateTransitionTable, value = action << 4 | state,
        # indexed by state << 8 | byte.
        TABLE = begin
          t = Array.new(4096, (NONE << 4) | GROUND)
          one = ->(code, state, action, nxt) { t[(state << 8) | code] = (action << 4) | nxt }
          many = ->(codes, state, action, nxt) { codes.each { |c| one.(c, state, action, nxt) } }

          (GROUND..UTF8).each do |s|
            many.([0x18, 0x1A, 0x99, 0x9A], s, EXECUTE, GROUND)
            many.(0x80..0x8F, s, EXECUTE, GROUND)
            many.(0x90..0x97, s, EXECUTE, GROUND)
            one.(0x9C, s, EXECUTE, GROUND)
            one.(0x1B, s, CLEAR, ESCAPE)
            one.(0x98, s, START, SOS_STRING)
            one.(0x9E, s, START, PM_STRING)
            one.(0x9F, s, START, APC_STRING)
            one.(0x9B, s, CLEAR, CSI_ENTRY)
            one.(0x90, s, CLEAR, DCS_ENTRY)
            one.(0x9D, s, START, OSC_STRING)
            many.(0xC2..0xDF, s, COLLECT, UTF8)
            many.(0xE0..0xEF, s, COLLECT, UTF8)
            many.(0xF0..0xF4, s, COLLECT, UTF8)
          end

          many.(0x00..0x17, GROUND, EXECUTE, GROUND)
          one.(0x19, GROUND, EXECUTE, GROUND)
          many.(0x1C..0x1F, GROUND, EXECUTE, GROUND)
          many.(0x20..0x7E, GROUND, PRINT, GROUND)
          one.(0x7F, GROUND, EXECUTE, GROUND)

          many.(0x00..0x17, ESCAPE_INTERMEDIATE, EXECUTE, ESCAPE_INTERMEDIATE)
          one.(0x19, ESCAPE_INTERMEDIATE, EXECUTE, ESCAPE_INTERMEDIATE)
          many.(0x1C..0x1F, ESCAPE_INTERMEDIATE, EXECUTE, ESCAPE_INTERMEDIATE)
          many.(0x20..0x2F, ESCAPE_INTERMEDIATE, COLLECT, ESCAPE_INTERMEDIATE)
          one.(0x7F, ESCAPE_INTERMEDIATE, IGNORE, ESCAPE_INTERMEDIATE)
          many.(0x30..0x7E, ESCAPE_INTERMEDIATE, DISPATCH, GROUND)

          many.(0x00..0x17, ESCAPE, EXECUTE, ESCAPE)
          one.(0x19, ESCAPE, EXECUTE, ESCAPE)
          many.(0x1C..0x1F, ESCAPE, EXECUTE, ESCAPE)
          one.(0x7F, ESCAPE, IGNORE, ESCAPE)
          many.(0x30..0x4F, ESCAPE, DISPATCH, GROUND)
          many.(0x51..0x57, ESCAPE, DISPATCH, GROUND)
          one.(0x59, ESCAPE, DISPATCH, GROUND)
          one.(0x5A, ESCAPE, DISPATCH, GROUND)
          one.(0x5C, ESCAPE, DISPATCH, GROUND)
          many.(0x60..0x7E, ESCAPE, DISPATCH, GROUND)
          many.(0x20..0x2F, ESCAPE, COLLECT, ESCAPE_INTERMEDIATE)
          one.(0x58, ESCAPE, START, SOS_STRING)
          one.(0x5E, ESCAPE, START, PM_STRING)
          one.(0x5F, ESCAPE, START, APC_STRING)
          one.(0x50, ESCAPE, CLEAR, DCS_ENTRY)
          one.(0x5B, ESCAPE, CLEAR, CSI_ENTRY)
          one.(0x5D, ESCAPE, START, OSC_STRING)

          (SOS_STRING..APC_STRING).each do |s|
            many.(0x00..0x17, s, PUT, s)
            one.(0x19, s, PUT, s)
            many.(0x1C..0x1F, s, PUT, s)
            many.(0x20..0x7F, s, PUT, s)
            one.(0x1B, s, DISPATCH, ESCAPE)
            one.(0x9C, s, DISPATCH, GROUND)
            many.([0x18, 0x1A], s, IGNORE, GROUND)
          end

          many.(0x00..0x07, DCS_ENTRY, IGNORE, DCS_ENTRY)
          many.(0x0E..0x17, DCS_ENTRY, IGNORE, DCS_ENTRY)
          one.(0x19, DCS_ENTRY, IGNORE, DCS_ENTRY)
          many.(0x1C..0x1F, DCS_ENTRY, IGNORE, DCS_ENTRY)
          one.(0x7F, DCS_ENTRY, IGNORE, DCS_ENTRY)
          many.(0x20..0x2F, DCS_ENTRY, COLLECT, DCS_INTERMEDIATE)
          many.(0x30..0x3B, DCS_ENTRY, PARAM, DCS_PARAM)
          many.(0x3C..0x3F, DCS_ENTRY, PREFIX, DCS_PARAM)
          many.(0x08..0x0D, DCS_ENTRY, PUT, DCS_STRING)
          one.(0x1B, DCS_ENTRY, PUT, DCS_STRING)
          many.(0x40..0x7E, DCS_ENTRY, START, DCS_STRING)

          many.(0x00..0x17, DCS_INTERMEDIATE, IGNORE, DCS_INTERMEDIATE)
          one.(0x19, DCS_INTERMEDIATE, IGNORE, DCS_INTERMEDIATE)
          many.(0x1C..0x1F, DCS_INTERMEDIATE, IGNORE, DCS_INTERMEDIATE)
          many.(0x20..0x2F, DCS_INTERMEDIATE, COLLECT, DCS_INTERMEDIATE)
          one.(0x7F, DCS_INTERMEDIATE, IGNORE, DCS_INTERMEDIATE)
          many.(0x30..0x3F, DCS_INTERMEDIATE, START, DCS_STRING)
          many.(0x40..0x7E, DCS_INTERMEDIATE, START, DCS_STRING)

          many.(0x00..0x17, DCS_PARAM, IGNORE, DCS_PARAM)
          one.(0x19, DCS_PARAM, IGNORE, DCS_PARAM)
          many.(0x1C..0x1F, DCS_PARAM, IGNORE, DCS_PARAM)
          many.(0x30..0x3B, DCS_PARAM, PARAM, DCS_PARAM)
          one.(0x7F, DCS_PARAM, IGNORE, DCS_PARAM)
          many.(0x3C..0x3F, DCS_PARAM, IGNORE, DCS_PARAM)
          many.(0x20..0x2F, DCS_PARAM, COLLECT, DCS_INTERMEDIATE)
          many.(0x40..0x7E, DCS_PARAM, START, DCS_STRING)

          many.(0x00..0x17, DCS_STRING, PUT, DCS_STRING)
          one.(0x19, DCS_STRING, PUT, DCS_STRING)
          many.(0x1C..0x1F, DCS_STRING, PUT, DCS_STRING)
          many.(0x20..0x7E, DCS_STRING, PUT, DCS_STRING)
          one.(0x7F, DCS_STRING, PUT, DCS_STRING)
          many.(0x80..0xFF, DCS_STRING, PUT, DCS_STRING)
          one.(0x1B, DCS_STRING, DISPATCH, ESCAPE)
          one.(0x9C, DCS_STRING, DISPATCH, GROUND)
          many.([0x18, 0x1A], DCS_STRING, IGNORE, GROUND)

          many.(0x00..0x17, CSI_PARAM, EXECUTE, CSI_PARAM)
          one.(0x19, CSI_PARAM, EXECUTE, CSI_PARAM)
          many.(0x1C..0x1F, CSI_PARAM, EXECUTE, CSI_PARAM)
          many.(0x30..0x3B, CSI_PARAM, PARAM, CSI_PARAM)
          one.(0x7F, CSI_PARAM, IGNORE, CSI_PARAM)
          many.(0x3C..0x3F, CSI_PARAM, IGNORE, CSI_PARAM)
          many.(0x40..0x7E, CSI_PARAM, DISPATCH, GROUND)
          many.(0x20..0x2F, CSI_PARAM, COLLECT, CSI_INTERMEDIATE)

          many.(0x00..0x17, CSI_INTERMEDIATE, EXECUTE, CSI_INTERMEDIATE)
          one.(0x19, CSI_INTERMEDIATE, EXECUTE, CSI_INTERMEDIATE)
          many.(0x1C..0x1F, CSI_INTERMEDIATE, EXECUTE, CSI_INTERMEDIATE)
          many.(0x20..0x2F, CSI_INTERMEDIATE, COLLECT, CSI_INTERMEDIATE)
          one.(0x7F, CSI_INTERMEDIATE, IGNORE, CSI_INTERMEDIATE)
          many.(0x40..0x7E, CSI_INTERMEDIATE, DISPATCH, GROUND)
          many.(0x30..0x3F, CSI_INTERMEDIATE, IGNORE, GROUND)

          many.(0x00..0x17, CSI_ENTRY, EXECUTE, CSI_ENTRY)
          one.(0x19, CSI_ENTRY, EXECUTE, CSI_ENTRY)
          many.(0x1C..0x1F, CSI_ENTRY, EXECUTE, CSI_ENTRY)
          one.(0x7F, CSI_ENTRY, IGNORE, CSI_ENTRY)
          many.(0x40..0x7E, CSI_ENTRY, DISPATCH, GROUND)
          many.(0x20..0x2F, CSI_ENTRY, COLLECT, CSI_INTERMEDIATE)
          many.(0x30..0x3B, CSI_ENTRY, PARAM, CSI_PARAM)
          many.(0x3C..0x3F, CSI_ENTRY, PREFIX, CSI_PARAM)

          many.(0x00..0x06, OSC_STRING, IGNORE, OSC_STRING)
          many.(0x08..0x17, OSC_STRING, IGNORE, OSC_STRING)
          one.(0x19, OSC_STRING, IGNORE, OSC_STRING)
          many.(0x1C..0x1F, OSC_STRING, IGNORE, OSC_STRING)
          many.(0x20..0xFF, OSC_STRING, PUT, OSC_STRING)
          one.(0x1B, OSC_STRING, DISPATCH, ESCAPE)
          one.(0x07, OSC_STRING, DISPATCH, GROUND)
          one.(0x9C, OSC_STRING, DISPATCH, GROUND)
          many.([0x18, 0x1A], OSC_STRING, IGNORE, GROUND)

          t.freeze
        end

        PLAIN = /[^\x20-\x7E]/n
        FFFD = "\u{FFFD}"
        private_constant :PLAIN, :FFFD

        module_function

        # x/ansi StringWidth: cells the string occupies; escape sequences
        # are zero-width.
        def string_width(str)
          s = str.b
          return 0 if s.empty?
          return s.bytesize unless s.match?(PLAIN)

          pstate = GROUND
          width = 0
          i = 0
          n = s.bytesize
          while i < n
            v = TABLE[(pstate << 8) | s.getbyte(i)]
            state = v & 15
            if state == UTF8
              len, w = first_grapheme_cluster(s, i)
              width += w
              i += len
              pstate = GROUND
              next
            end
            width += 1 if (v >> 4) == PRINT
            pstate = state
            i += 1
          end
          width
        end

        # x/ansi Truncate(s, length, ""): cut the string to at most `length`
        # cells, keeping every escape sequence (including those after the cut).
        def truncate(str, length, tail = "")
          return str if string_width(str) <= length

          length -= string_width(tail)
          return +"" if length.negative?

          b = str.b
          buf = +"".b
          tail = tail.b
          cur_width = 0
          ignoring = false
          pstate = GROUND
          i = 0
          n = b.bytesize
          while i < n
            byte = b.getbyte(i)
            v = TABLE[(pstate << 8) | byte]
            state = v & 15
            if state == UTF8
              len, width = first_grapheme_cluster(b, i)
              cluster_start = i
              i += len
              next if ignoring

              if cur_width + width > length
                ignoring = true
                buf << tail
                next
              end

              cur_width += width
              buf << b.byteslice(cluster_start, len)
              pstate = GROUND
              next
            end

            if (v >> 4) == PRINT
              if cur_width >= length && !ignoring
                ignoring = true
                buf << tail
              end
              if ignoring
                i += 1
                next
              end
              cur_width += 1
            end
            buf << byte
            i += 1

            pstate = state
            if cur_width > length && !ignoring
              ignoring = true
              buf << tail
            end
          end

          buf.force_encoding(str.encoding)
        end

        # uniseg FirstGraphemeCluster(b[i:], -1): byte length and width of
        # the grapheme cluster starting at byte i.
        def first_grapheme_cluster(bytes, i)
          want = 8
          loop do
            runes, lens, done = decode_runes(bytes, i, want)
            text = runes.pack("U*")
            cluster = text[/\A\X/m]
            count = cluster.length
            if count < runes.length || done
              return [lens.first(count).sum, cluster_width(runes.first(count))]
            end

            want *= 2
          end
        end

        # Decodes up to `max` runes from byte i the way Go's utf8.DecodeRune
        # does: invalid bytes become U+FFFD, one byte each.
        def decode_runes(bytes, i, max)
          runes = []
          lens = []
          n = bytes.bytesize
          while i < n && runes.length < max
            lead = bytes.getbyte(i)
            size = if lead < 0x80 then 1
                   elsif lead >= 0xC2 && lead <= 0xDF then 2
                   elsif lead >= 0xE0 && lead <= 0xEF then 3
                   elsif lead >= 0xF0 && lead <= 0xF4 then 4
                   else 0
                   end
            char = size.positive? && bytes.byteslice(i, size).force_encoding(Encoding::UTF_8)
            if char && char.bytesize == size && char.valid_encoding?
              runes << char.ord
              lens << size
              i += size
            else
              runes << 0xFFFD
              lens << 1
              i += 1
            end
          end
          [runes, lens, i >= n]
        end

        # uniseg's width for one cluster: the first rune's width; then for
        # Extended_Pictographic VS15/VS16 set 1/2, for regional indicators
        # and Hangul L nothing is added, otherwise each rune's width adds.
        def cluster_width(runes)
          first = runes.first
          width = WidthTable.width(first)
          if WidthTable.extended_pictographic?(first)
            runes.drop(1).each do |r|
              if r == VS15 then width = 1
              elsif r == VS16 then width = 2
              end
            end
          elsif !WidthTable.width_of_first_only?(first)
            runes.drop(1).each { |r| width += WidthTable.width(r) }
          end
          width
        end
      end
    end
  end
end
