# frozen_string_literal: true

module R2UI
  module Compat
    module Tea
      # Pure-Ruby port of bubbletea 0.1.4's Go input parser (go/keys.go:
      # ParseInput, parseMouseSGR, parseInts, keyNames, tea_get_key_name).
      # Each event is the Hash that JSON.parse returns for Go's json.Marshal
      # of the event struct, so Bubbletea.parse_event consumes it unchanged.
      module Input
        KEY_RUNES = -1
        KEY_ESC = 27
        KEY_SPACE = -25

        KEY_NAMES = {
          0 => "ctrl+@", 1 => "ctrl+a", 2 => "ctrl+b", 3 => "ctrl+c", 4 => "ctrl+d",
          5 => "ctrl+e", 6 => "ctrl+f", 7 => "ctrl+g", 8 => "ctrl+h", 9 => "tab",
          10 => "ctrl+j", 11 => "ctrl+k", 12 => "ctrl+l", 13 => "enter", 14 => "ctrl+n",
          15 => "ctrl+o", 16 => "ctrl+p", 17 => "ctrl+q", 18 => "ctrl+r", 19 => "ctrl+s",
          20 => "ctrl+t", 21 => "ctrl+u", 22 => "ctrl+v", 23 => "ctrl+w", 24 => "ctrl+x",
          25 => "ctrl+y", 26 => "ctrl+z", 27 => "esc", 127 => "backspace",
          -1 => "runes", -2 => "up", -3 => "down", -4 => "right", -5 => "left",
          -6 => "home", -7 => "end", -8 => "pgup", -9 => "pgdown", -10 => "delete",
          -11 => "insert", -12 => "f1", -13 => "f2", -14 => "f3", -15 => "f4",
          -16 => "f5", -17 => "f6", -18 => "f7", -19 => "f8", -20 => "f9",
          -21 => "f10", -22 => "f11", -23 => "f12", -24 => "shift+tab", -25 => "space"
        }.freeze

        # No sequence is a prefix of another, so Go's random map iteration
        # order never changes the result.
        ESCAPE_SEQUENCES = {
          "\e[A" => -2, "\e[B" => -3, "\e[C" => -4, "\e[D" => -5,
          "\e[H" => -6, "\e[F" => -7, "\e[1~" => -6, "\e[4~" => -7,
          "\e[5~" => -8, "\e[6~" => -9, "\e[2~" => -11, "\e[3~" => -10,
          "\eOP" => -12, "\eOQ" => -13, "\eOR" => -14, "\eOS" => -15,
          "\e[15~" => -16, "\e[17~" => -17, "\e[18~" => -18, "\e[19~" => -19,
          "\e[20~" => -20, "\e[21~" => -21, "\e[23~" => -22, "\e[24~" => -23,
          "\e[Z" => -24,
          # Upstream placeholders for shift/ctrl arrows; they have no name.
          "\e[1;2A" => -100, "\e[1;2B" => -101, "\e[1;2C" => -102, "\e[1;2D" => -103,
          "\e[1;5A" => -104, "\e[1;5B" => -105, "\e[1;5C" => -106, "\e[1;5D" => -107
        }.each_with_object({}) { |(k, v), h| h[k.b.freeze] = v }.freeze

        PASTE_START = "\e[200~".b.freeze
        PASTE_END = "\e[201~".b.freeze

        module_function

        # Go tea_get_key_name: "" for unknown types.
        def key_name(key_type)
          KEY_NAMES.fetch(key_type, "")
        end

        # Go ParseInput: returns [consumed, event_hash_or_nil].
        def parse(bytes)
          data = bytes.b
          return [0, nil] if data.empty?

          b0 = data.getbyte(0)
          b1 = data.getbyte(1)

          if data.bytesize >= 3 && b0 == 0x1b && b1 == 0x5b
            b2 = data.getbyte(2)
            return [3, { "type" => "focus", "focus" => true }] if b2 == 0x49 # I
            return [3, { "type" => "blur", "focus" => false }] if b2 == 0x4f # O
          end

          if data.bytesize >= 6 && b0 == 0x1b && b1 == 0x5b && data.getbyte(2) == 0x3c
            consumed, mouse = parse_mouse_sgr(data)
            return [consumed, mouse] if consumed.positive?
          end

          if b0 == 0x1b && data.bytesize > 1
            ESCAPE_SEQUENCES.each do |seq, key_type|
              next unless data.start_with?(seq)

              name = KEY_NAMES.fetch(key_type, "")
              name = "unknown" if name.empty?
              return [seq.bytesize, key_event(key_type, nil, false, name)]
            end

            if b1 >= 32 && b1 < 127
              char = b1.chr
              return [2, key_event(KEY_RUNES, [b1], true, "alt+#{char}")]
            end

            return [1, key_event(KEY_ESC, nil, false, "esc")]
          end

          if b0 < 32 || b0 == 127
            name = KEY_NAMES.fetch(b0, "")
            name = "ctrl+?" if name.empty?
            return [1, key_event(b0, nil, false, name)]
          end

          return [1, key_event(KEY_SPACE, [32], false, "space")] if b0 == 0x20

          size = utf8_size(data)
          return [1, nil] unless size

          char = data.byteslice(0, size).force_encoding(Encoding::UTF_8)
          [size, key_event(KEY_RUNES, [char.ord], false, char)]
        end

        # Decodes every event in one read chunk, in order, plus bracketed paste.
        def parse_all(bytes)
          data = bytes.b
          events = []
          pos = 0
          while pos < data.bytesize
            rest = data.byteslice(pos, data.bytesize - pos)
            if rest.start_with?(PASTE_START)
              body = rest.byteslice(PASTE_START.bytesize, rest.bytesize - PASTE_START.bytesize)
              stop = body.index(PASTE_END)
              text = stop ? body.byteslice(0, stop) : body
              events << paste_event(text)
              pos += PASTE_START.bytesize + text.bytesize + (stop ? PASTE_END.bytesize : 0)
              next
            end

            consumed, event = parse(rest)
            break if consumed <= 0

            events << event if event
            pos += consumed
          end
          events
        end

        def key_event(key_type, runes, alt, name)
          { "type" => "key", "key_type" => key_type, "runes" => runes, "alt" => alt, "name" => name }
        end

        def paste_event(bytes)
          text = bytes.dup.force_encoding(Encoding::UTF_8).scrub
          { "type" => "key", "key_type" => KEY_RUNES, "runes" => text.codepoints,
            "alt" => false, "name" => "[#{text}]", "paste" => true }
        end

        # Go parseMouseSGR: ESC [ < Cb ; Cx ; Cy (M|m). Returns [0, nil] on failure.
        def parse_mouse_sgr(data)
          end_index = nil
          i = 3
          while i < data.bytesize && i < 32
            byte = data.getbyte(i)
            if byte == 0x4d || byte == 0x6d # M / m
              end_index = i
              break
            end
            i += 1
          end
          return [0, nil] unless end_index

          count, (button, x, y) = parse_ints(data.byteslice(3, end_index - 3), 3)
          return [0, nil] unless count == 3

          button_num = button & 3
          action = if data.getbyte(end_index) == 0x6d then 1
                   elsif button.anybits?(32) then 2
                   else 0
                   end
          if button.anybits?(64)
            if button_num.zero? then button_num = 4
            elsif button_num == 1 then button_num = 5
            end
          end

          [end_index + 1, {
            "type" => "mouse", "x" => x - 1, "y" => y - 1, "button" => button_num, "action" => action,
            "shift" => button.anybits?(4), "alt" => button.anybits?(8), "ctrl" => button.anybits?(16)
          }]
        end

        # Go parseInts: empty fields are skipped (slot left 0, not counted);
        # a non-digit stops parsing and returns the count so far.
        def parse_ints(str, slots)
          vals = Array.new(slots, 0)
          count = 0
          start = 0
          index = 0
          i = 0
          while i <= str.bytesize && index < slots
            if i == str.bytesize || str.getbyte(i) == 0x3b
              if i > start
                num = 0
                (start...i).each do |j|
                  d = str.getbyte(j)
                  return [count, vals] if d < 0x30 || d > 0x39

                  num = (num * 10) + (d - 0x30)
                end
                vals[index] = num
                count += 1
              end
              index += 1
              start = i + 1
            end
            i += 1
          end
          [count, vals]
        end

        # Byte length of the valid UTF-8 rune at the start of data, or nil
        # where Go's utf8.DecodeRune returns (RuneError, 1).
        def utf8_size(data)
          b0 = data.getbyte(0)
          len = if b0 < 0x80 then 1
                elsif b0 >= 0xc2 && b0 <= 0xdf then 2
                elsif b0 >= 0xe0 && b0 <= 0xef then 3
                elsif b0 >= 0xf0 && b0 <= 0xf4 then 4
                end
          return nil unless len && data.bytesize >= len

          data.byteslice(0, len).force_encoding(Encoding::UTF_8).valid_encoding? ? len : nil
        end
      end
    end
  end
end
