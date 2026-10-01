# frozen_string_literal: true

require_relative "../../format"

# c14-format: numbers and links the way people read them.
#
#   say "added #{plural(1234, "package")} in #{duration(75.2)}"   # added 1,234 packages in 1m 15s
#   say "#{bytes(1_500_000)} written"                             # 1.5 MB written
#   say "#{ibytes(1536)} in cache"                                # 1.5K in cache
#   say "#{plural(1, "child", "children")}"                       # 1 child
#   say "opened #{link(pr.url, "PR ##{pr.number}")}"
#
# duration(seconds)       "120ms" under a second, "3.5s" under a minute, then "1m 15s", "2h 30m",
#                         "1d 2h". It rounds before picking the unit, so 59.97 is "1m 0s".
# bytes(count)            SI (decimal) units like npm and the OS file managers: "999 B", "12 kB",
#                         "1.5 MB", "4.2 GB" (one decimal under 10, none above).
# ibytes(count)           binary units like the dashboard's :bytes column: "999B", "1.0K", "1.5K",
#                         "10K", "400M" (1024 per step; switches unit before reaching 1000).
# plural(count, word,     "3 packages", "1 package", "2 dependencies", "2 boxes"; counts get
#        plural = nil)    thousands separators. Pass the plural for irregular words.
# link(url, text = url)   on a terminal with colour, an OSC 8 hyperlink: "text", clickable to url
#                         (terminals without OSC 8 support show just "text"). Off a terminal, or
#                         with NO_COLOR, plain "text (url)", or just "url" when there's no text.
#
# duration, bytes, ibytes and plural all come from R2UI::Format (shared with the dashboards) and
# are the same on and off a terminal; only link looks at the shell.
module R2UI
  module CLI
    module Ext
      # Kept for back compatibility; the formats live in R2UI::Format.
      module HumanFormat
        module_function

        def duration(seconds) = R2UI::Format.duration(seconds)

        def bytes(count) = R2UI::Format.si_bytes(count)

        def plural(count, word, plural = nil) = R2UI::Format.plural(count, word, plural)

        def pluralize(word) = R2UI::Format.pluralize(word)

        def delimit(count) = R2UI::Format.delimit(count)

        def link(shell, url, text)
          return text.nil? || text == url ? url.to_s : "#{text} (#{url})" unless shell.color?

          "\e]8;;#{url}\e\\#{text || url}\e]8;;\e\\"
        end
      end
    end

    extension :format do
      helpers do
        def duration(seconds) = R2UI::Format.duration(seconds)

        def bytes(count) = R2UI::Format.si_bytes(count)

        def ibytes(count) = R2UI::Format.bytes(count)

        def plural(count, word, plural = nil) = R2UI::Format.plural(count, word, plural)

        def link(url, text = nil) = Ext::HumanFormat.link(shell, url, text)
      end
    end
  end
end
