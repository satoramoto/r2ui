# frozen_string_literal: true

# c05-progress: a progress bar with rate and ETA.
#
#   progress(total: 10_000_000, title: "Downloading", unit: :bytes) do |bar|
#     download { |chunk| bar.advance(chunk.bytesize) }   # or bar.current = n; bar.total = n
#   end                                                  # => the block's value
#
# On a terminal (Shell#live?) one line redraws in place, the bar sized to the width and filled
# with a lipgloss colour blend:
#
#   Downloading ━━━━━━━━━━━╸─────────────── 42% 4.2/10 MB · 1.3 MB/s · ETA 4s
#
# and resolves to "✔ Downloading 10 MB 7.6s" (or "✖ Downloading 4.2/10 MB 3.1s" when the block
# raises; the exception propagates, so a command exits 1, or 130 on ctrl+c). On a narrow terminal
# the ETA, rate and amount drop off before the bar gets too short. `total: nil` (or `bar.total =
# nil`) shows an indeterminate bar: a segment sweeping across, and the amount so far.
#
# Off a terminal it prints "Downloading 25%", "Downloading 50%" and "Downloading 75%" as the bar
# passes them, then the resolved line: no bar, no escape codes.
#
# `unit:` is :bytes (sizes like "4.2 MB", rates "1.3 MB/s"), a label ("files": "12/40 files",
# "3 files/s") or nil (plain counts). `say` inside the block prints above the bar.
module R2UI
  module CLI
    module Ext
      module Progress
        FILL = "━"
        HALF = "╸"
        TRACK = "─"
        # bubbles progress's default gradient.
        GRADIENT = %w[#5A56E0 #EE6FF8].freeze
        MIN_BAR = 10
        MAX_BAR = 50
        MILESTONES = [25, 50, 75].freeze
        RATE_WINDOW = 5.0 # seconds of samples the rate is measured over
        BYTE_UNITS = %w[B kB MB GB TB PB].freeze

        # What the block gets: move the bar.
        class Handle
          def initialize(bar) = @bar = bar

          def advance(by = 1) = @bar.update { |b| b.current + by }

          def current = @bar.current

          def current=(value)
            @bar.update { value }
          end

          def total = @bar.total

          def total=(value)
            @bar.set_total(value)
          end

          def title = @bar.title

          def title=(text)
            @bar.title = text.to_s
          end
        end

        # One bar: its numbers, how it draws on a terminal and what it prints off one.
        class Bar
          attr_reader :current, :total, :title

          def initialize(shell, total:, title:, unit:)
            @shell = shell
            @total = Progress.check_total(total)
            @title = title.to_s
            @unit = unit
            @current = 0
            @status = :running
            @lock = Monitor.new
            @milestone = 0
            @styles = {}
          end

          def title=(text)
            @lock.synchronize { @title = text }
            @live&.refresh
          end

          def set_total(value)
            @lock.synchronize { @total = Progress.check_total(value) }
            changed
          end

          def update
            value = yield self
            raise ArgumentError, "progress needs a number, got #{value.inspect}" unless value.is_a?(Numeric)

            @lock.synchronize do
              @current = value
              sample
            end
            changed
          end

          # Runs the block with the bar drawing (on a terminal) and returns its value.
          def run(&block)
            @started = now
            @samples = [[@started, @current]]
            # Inside another live region (a tasks step) there is one region per shell: print plain.
            @live = Live.new(@shell) { |frame| view(frame) } unless @shell.live
            body = lambda do
              value = block.call(Handle.new(self))
              finish(:done)
              value
            rescue Exception => e # rubocop:disable Lint/RescueException -- ctrl+c and halt end the bar too
              finish(e.is_a?(Halt) ? :done : :failed)
              raise
            end
            @live ? @live.run { body.call } : body.call
          end

          def view(frame)
            @lock.synchronize { @status == :running ? running_line(frame) : resolved_line }
          end

          private

          def drawing? = @live&.running?

          def finish(status)
            @lock.synchronize do
              @status = status
              @finished = now
            end
            @shell.puts(resolved_line) unless drawing?
          end

          # Off a terminal: the milestones passed. On one: redraw when the percent changes.
          def changed
            percent = @lock.synchronize { self.percent }
            if drawing?
              @live.refresh if percent != @drawn_percent
              @drawn_percent = percent
            elsif percent && @total.positive?
              MILESTONES.each do |m|
                next if m <= @milestone || percent < m

                @milestone = m
                @shell.puts("#{@title} #{m}%")
              end
            end
          end

          def ratio
            return nil if @total.nil?
            return 1.0 if @total.zero?

            (@current.to_f / @total).clamp(0.0, 1.0)
          end

          # Whole percent done, rounded down in exact arithmetic (100 only when complete).
          def percent
            return nil if @total.nil?
            return 100 if @total.zero?

            (@current.to_r * 100 / @total).floor.clamp(0, 100)
          end

          # Keeps a few seconds of [time, current] samples (at most ten a second) for the rate.
          def sample
            t = now
            @samples << [t, @current] if t - @samples.last[0] >= 0.1
            @samples.shift while @samples.size > 1 && t - @samples[1][0] > RATE_WINDOW
          end

          def rate
            t0, c0 = @samples.first
            span = now - t0
            return nil if span < 0.2

            per_second = (@current - c0) / span
            per_second.positive? ? per_second : nil
          end

          def running_line(frame)
            r = ratio
            percent = r && "#{self.percent}%"
            per_second = rate
            parts = [amount(with_total: true)]
            parts << "#{Progress.amount(per_second, @unit)}/s" if per_second
            parts << "ETA #{Progress.eta((@total - @current) / per_second)}" if per_second && r && r < 1

            # Drop the ETA, then the rate, then the amount before the bar gets shorter than MIN_BAR.
            loop do
              tail = [percent, parts.join(" · ")].reject { |s| s.nil? || s.empty? }.join(" ")
              # Spaces around the bar, and the last column left free so the line never wraps.
              used = Lipgloss.width(@title) + (tail.empty? ? 0 : Lipgloss.width(tail) + 1) + 2
              width = @shell.width - used
              if width >= MIN_BAR || parts.empty?
                bar = width.positive? ? bar(steady(width.clamp(1, MAX_BAR)), r, frame) : nil
                info = parts.empty? ? nil : @shell.paint(parts.join(" · "), :muted)
                return [@title, bar, percent, info].compact.join(" ")
              end
              parts.pop
            end
          end

          # The bar only shrinks while the terminal keeps its width, so an ETA going from "10s" to
          # "9s" doesn't make it twitch.
          def steady(width)
            @steady = nil if @steady && @steady[0] != @shell.width
            @steady = [@shell.width, [width, @steady&.last || width].min]
            @steady.last
          end

          def resolved_line
            time = @shell.paint(Progress.duration(@finished - @started), :muted)
            if @status == :failed
              "#{@shell.symbol(:error)} #{@title} #{amount(with_total: true)} #{time}"
            else
              "#{@shell.symbol(:success)} #{@title} #{amount(with_total: false)} #{time}"
            end
          end

          def amount(with_total:)
            return Progress.amount(@current, @unit) unless with_total && @total

            Progress.amount_of(@current, @total, @unit)
          end

          def bar(width, r, frame)
            colors = (@gradients ||= {})[width] ||= Lipgloss::ColorBlend.blends(*GRADIENT, width)
            cells = Array.new(width) { [TRACK, nil] }
            if r
              halves = (r * width * 2).floor
              (halves / 2).times { |i| cells[i] = [FILL, colors[i]] }
              cells[halves / 2] = [HALF, colors[halves / 2]] if halves.odd?
            else
              segment = (width / 4).clamp(3, 12).clamp(1, width)
              span = width - segment
              pos = span.zero? ? 0 : frame % (2 * span)
              pos = (2 * span) - pos if pos > span
              segment.times { |i| cells[pos + i] = [FILL, colors[pos + i]] }
            end
            cells.chunk { |glyph, color| [glyph == TRACK, color] }.map do |(track, color), run|
              text = run.map(&:first).join
              track ? @shell.paint(text, :muted) : paint_color(text, color)
            end.join
          end

          def paint_color(text, color)
            return text unless @shell.color?

            (@styles[color] ||= Lipgloss::Style.new.foreground(color)).render(text)
          end

          def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        module_function

        def check_total(total)
          return nil if total.nil?
          raise ArgumentError, "progress total must be a number, got #{total.inspect}" unless total.is_a?(Numeric)
          raise ArgumentError, "progress total can't be negative" if total.negative?

          total
        end

        # 4_200_000, :bytes → "4.2 MB"; 12, "files" → "12 files"; 12, nil → "12".
        def amount(n, unit)
          return "#{number(n / (1000.0**byte_exponent(n)), byte_exponent(n))} #{BYTE_UNITS[byte_exponent(n)]}" if unit == :bytes

          [number(n, 0), unit].compact.join(" ")
        end

        # 4_200_000 of 10_000_000, :bytes → "4.2/10 MB" (in the total's unit); 3, 10 → "3/10".
        def amount_of(n, total, unit)
          if unit == :bytes
            e = byte_exponent(total)
            scale = 1000.0**e
            return "#{number(n / scale, e)}/#{number(total / scale, e)} #{BYTE_UNITS[e]}"
          end

          ["#{number(n, 0)}/#{number(total, 0)}", unit].compact.join(" ")
        end

        def byte_exponent(n)
          e = 0
          e += 1 while n.abs >= 1000**(e + 1) && e < BYTE_UNITS.size - 1
          e
        end

        # Whole numbers stay whole; scaled ones and fractions under 10 keep one decimal.
        def number(value, exponent)
          return value.to_s if value.is_a?(Integer)
          return value.round.to_s if value.abs >= 10 || (exponent.zero? && value == value.round)

          format("%.1f", value).delete_suffix(".0")
        end

        # Seconds left: "4s", "1m 5s", "2h 3m".
        def eta(seconds)
          s = seconds.ceil
          return "#{s}s" if s < 60
          return "#{s / 60}m #{s % 60}s" if s < 3600

          "#{s / 3600}h #{(s % 3600) / 60}m"
        end

        # 0.12 → "120ms", 3.456 → "3.5s", 75 → "1m 15s" (the tasks story's format).
        def duration(seconds)
          return "#{(seconds * 1000).round}ms" if (seconds * 1000).round < 1000

          tenths = (seconds * 10).round
          return "#{format("%.1f", tenths / 10.0)}s" if tenths < 600

          total = seconds.round
          "#{total / 60}m #{total % 60}s"
        end
      end
    end

    extension :progress do
      helpers do
        def progress(total: nil, title: "Working", unit: nil, &block)
          raise ArgumentError, "progress needs a block" unless block

          Ext::Progress::Bar.new(shell, total:, title:, unit:).run(&block)
        end
      end
    end
  end
end
