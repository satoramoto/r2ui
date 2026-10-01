# frozen_string_literal: true

# c04-spinner: one spinner line while some work runs (ora, gum spin), resolving to a ✔ / ✖ line.
#
#   spin("Installing", done: "Installed") do |s|
#     packages.each_with_index { |pkg, i| s.text = "Installing #{pkg} (#{i + 1}/#{packages.size})"; install(pkg) }
#   end
#
#   files = spin("Scanning", done: ->(found) { "Found #{found.size} files" }) { scan }
#   spin("Checking for updates", clear: true) { check }   # vanishes when it succeeds
#
# On a terminal (Shell#live?) it draws one line, redrawn in place, the cursor hidden meanwhile:
#
#   ⠹ Installing react (3/12)
#
# and resolves to
#
#   ✔ Installed 1.2s
#
# The block's handle sets the text shown while it runs (`s.text = "..."`). `done:` is the
# resolved text: a String, or a lambda given the block's value; it defaults to the title. When the
# block raises, the line resolves to "✖ Installing" (the title) and the exception propagates (a
# command then exits 1 with "✖ message"; ctrl+c exits 130). `clear: true` erases the line when the
# block succeeds and prints nothing (a failure still leaves its ✖ line). `say` inside prints
# above the spinner. `spin` returns the block's value.
#
# Off a terminal (a pipe, CI, TERM=dumb) it prints only the resolved line ("✔ Installed 1.2s"),
# nothing while it runs: no spinner frames, no escape codes.
#
# Inside another live region (a running `tasks` step or another `spin`) the inner spin doesn't
# draw a second region: its resolved line prints above the outer one.
module R2UI
  module CLI
    module Ext
      module Spin
        # What the block gets: change the text shown beside the spinner.
        class Handle
          def initialize(line)
            @line = line
          end

          def text = @line.text

          def text=(value)
            @line.text = value.to_s
          end
        end

        # One spinner line: what it shows, how it runs and how it resolves.
        class Line
          def initialize(shell, title, done:, clear:)
            @shell = shell
            @title = title.to_s
            @done = done
            @clear = clear
            @text = @title
            @status = :running
            @lock = Monitor.new
          end

          def text = @lock.synchronize { @text }

          def text=(value)
            @lock.synchronize { @text = value }
            @live&.refresh
          end

          # Runs the block; returns its value, or re-raises its exception once the line resolved.
          def run(block)
            @started = now
            if @shell.live? && @shell.live.nil?
              @live = Live.new(@shell) { |frame| view(frame) }
              @live.run { call(block) }
            else
              call(block)
            end
            raise @error if @error

            @value
          end

          private

          def call(block)
            begin
              @value = block.call(Handle.new(self))
            rescue Exception => e # rubocop:disable Lint/RescueException -- ctrl+c and halt resolve the line too
              @error = e
            end
            resolve(@error && !@error.is_a?(Halt) ? :failed : :done)
          end

          def resolve(status)
            elapsed = now - @started
            text = @title
            begin
              text = done_text if status == :done
            rescue StandardError => e # a `done:` lambda that raises fails the line with its error
              status = :failed
              @error = e
            end
            @lock.synchronize do
              @status = status
              @elapsed = elapsed
              @resolved = text
            end
            cleared = @clear && status == :done
            if @live&.running?
              @live.clear = cleared
              @live.refresh unless cleared
            elsif !cleared
              @shell.puts(view(0))
            end
          end

          def view(frame)
            @lock.synchronize do
              case @status
              when :running then "#{@shell.paint(Live.spinner(frame), :running)} #{@text}"
              when :done
                "#{@shell.symbol(:success)} #{@resolved} #{@shell.paint(Spin.duration(@elapsed), :muted)}"
              when :failed then "#{@shell.symbol(:error)} #{@resolved}"
              end
            end
          end

          # The ✔ text: `done:` as given, or its lambda's result for the block's value (the title
          # when a halt left no value).
          def done_text
            case @done
            when nil then @title
            when Proc then @error ? @title : @done.call(@value).to_s
            else @done.to_s
            end
          end

          def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        module_function

        # 0.12 → "120ms", 3.456 → "3.5s", 75 → "1m 15s" (the same format as the task list's).
        def duration(seconds)
          return "#{(seconds * 1000).round}ms" if (seconds * 1000).round < 1000

          tenths = (seconds * 10).round
          return "#{format("%.1f", tenths / 10.0)}s" if tenths < 600

          total = seconds.round
          "#{total / 60}m #{total % 60}s"
        end
      end
    end

    extension :spinner do
      helpers do
        def spin(title, done: nil, clear: false, &block)
          raise ArgumentError, "spin needs a block" unless block

          Ext::Spin::Line.new(shell, title, done:, clear:).run(block)
        end
      end
    end
  end
end
