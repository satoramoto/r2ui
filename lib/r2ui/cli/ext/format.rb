# frozen_string_literal: true

# c14-format: numbers and links the way people read them.
#
#   say "added #{plural(1234, "package")} in #{duration(75.2)}"   # added 1,234 packages in 1m 15s
#   say "#{bytes(1_500_000)} written"                             # 1.5 MB written
#   say "#{plural(1, "child", "children")}"                       # 1 child
#   say "opened #{link(pr.url, "PR ##{pr.number}")}"
#
# duration(seconds)       "120ms" under a second, "3.5s" under a minute, then "1m 15s", "2h 30m",
#                         "1d 2h". It rounds before picking the unit, so 59.97 is "1m 0s".
# bytes(count)            decimal units like npm and the OS file managers: "999 B", "12 kB",
#                         "1.5 MB", "4.2 GB" (one decimal under 10, none above).
# plural(count, word,     "3 packages", "1 package", "2 dependencies", "2 boxes"; counts get
#        plural = nil)    thousands separators. Pass the plural for irregular words.
# link(url, text = url)   on a terminal with colour, an OSC 8 hyperlink: "text", clickable to url
#                         (terminals without OSC 8 support show just "text"). Off a terminal, or
#                         with NO_COLOR, plain "text (url)", or just "url" when there's no text.
#
# duration, bytes and plural are the same on and off a terminal; only link looks at the shell.
module R2UI
  module CLI
    module Ext
      module HumanFormat
        BYTE_UNITS = %w[B kB MB GB TB PB EB].freeze

        module_function

        def duration(seconds)
          seconds = Float(seconds)
          return "-#{duration(-seconds)}" if seconds.negative?

          ms = (seconds * 1000).round
          return "#{ms}ms" if ms < 1000

          tenths = (seconds * 10).round
          return "#{format("%.1f", tenths / 10.0)}s" if tenths < 600

          total = seconds.round
          return "#{total / 60}m #{total % 60}s" if total < 3600

          minutes = (total / 60.0).round
          return "#{minutes / 60}h #{minutes % 60}m" if minutes < 24 * 60

          hours = (total / 3600.0).round
          "#{hours / 24}d #{hours % 24}h"
        end

        def bytes(count)
          count = Float(count)
          return "-#{bytes(-count)}" if count.negative?

          # Rounds before picking the unit, so 999_999 is "1 MB", not "1000 kB".
          unit = 0
          unit += 1 while unit < BYTE_UNITS.size - 1 && scaled(count, unit) >= 1000
          value = scaled(count, unit)
          "#{value == value.to_i ? value.to_i : value} #{BYTE_UNITS[unit]}"
        end

        def scaled(count, unit)
          value = count / (1000**unit)
          value < 10 && unit.positive? ? value.round(1) : value.round
        end

        def plural(count, word, plural = nil)
          form = count == 1 ? word : plural || pluralize(word)
          "#{delimit(count)} #{form}"
        end

        def link(shell, url, text)
          return text.nil? || text == url ? url.to_s : "#{text} (#{url})" unless shell.color?

          "\e]8;;#{url}\e\\#{text || url}\e]8;;\e\\"
        end

        def pluralize(word)
          case word
          when /[^aeiou]y\z/i then "#{word[0..-2]}ies"
          when /(?:s|x|z|ch|sh)\z/i then "#{word}es"
          else "#{word}s"
          end
        end

        def delimit(count)
          whole, fraction = count.to_s.split(".", 2)
          whole = whole.reverse.scan(/\d{1,3}/).join(",").reverse.then { |w| whole.start_with?("-") ? "-#{w}" : w }
          fraction ? "#{whole}.#{fraction}" : whole
        end
      end
    end

    extension :format do
      helpers do
        def duration(seconds) = Ext::HumanFormat.duration(seconds)

        def bytes(count) = Ext::HumanFormat.bytes(count)

        def plural(count, word, plural = nil) = Ext::HumanFormat.plural(count, word, plural)

        def link(url, text = nil) = Ext::HumanFormat.link(shell, url, text)
      end
    end
  end
end
