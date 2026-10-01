# frozen_string_literal: true

# c02-tasks: an npm-style task list. Steps show as pending, spin while they run and resolve to
# ✔ / ✖ / – lines with their timings.
#
#   tasks do
#     step("Resolving packages") { resolve }                       # the block's value is kept
#     step("Fetching") { |s| files.each_with_index { |f, i| s.detail = "#{i + 1}/#{files.size}"; get(f) } }
#     step("Linking") { |s| s.skip!("nothing to link") if links.empty?; link }
#   end                                                            # => [resolved, fetched, linked]
#
# On a terminal (Shell#live?) the list redraws in place:
#
#   ✔ Resolving packages 120ms
#   ⠹ Fetching · 12/40
#   ○ Linking
#
# and its final state stays in the scrollback. Off a terminal each step prints one line when it
# ends ("✔ Resolving packages 120ms"), nothing else: no spinner frames, no escape codes.
#
# The `tasks` block declares the steps; they run after it, in order, on the caller's thread (so
# they see `args`, `options` and every helper). When a step raises, it shows ✖, the steps after it
# show "– skipped" without running, and the exception propagates (a command then exits 1 with
# "✖ message"; ctrl+c exits 130). `s.skip!(reason)` ends a step as skipped and carries on.
# `say`/`shell.puts` inside a step prints above the list.
#
# `step("Building") { ... }` outside a `tasks` block is a one-step list: it runs at once and
# returns the block's value.
#
# This is the reference extension for output helpers (docs/cli.md): a `helpers` block, a Live
# region for the terminal, one plain line per event off it. Copy its shape and its test.
module R2UI
  module CLI
    module Ext
      module Tasks
        # A step that ended early by choice (Handle#skip!).
        class Skip < StandardError; end

        Step = Struct.new(:title, :block, :status, :detail, :note, :started, :finished, :value) do
          def elapsed = finished && started ? finished - started : nil
        end

        # What a step's block gets: change its title or detail line while it runs, or skip it.
        class Handle
          def initialize(step, live)
            @step = step
            @live = live
          end

          def title = @step.title

          def title=(text)
            @step.title = text.to_s
            @live.refresh
          end

          def detail=(text)
            @step.detail = text&.to_s
            @live.refresh
          end

          def skip!(reason = nil) = raise(Skip, reason)
        end

        # The steps a `tasks` block declared, and how they run and draw.
        class List
          def initialize(shell)
            @shell = shell
            @steps = []
            @lock = Monitor.new
          end

          def add(title, block)
            raise ArgumentError, "step needs a block" unless block

            @steps << Step.new(title: title.to_s, block:, status: :pending)
          end

          # Runs every step; returns their values. Re-raises the first step's exception.
          def run
            error = nil
            live = Live.new(@shell) { |frame| view(frame) }
            live.run do
              @steps.each do |step|
                if error
                  finish(step, :skipped, live)
                  next
                end
                error = run_step(step, live)
              end
            end
            raise error if error

            @steps.map(&:value)
          end

          def view(frame)
            @lock.synchronize { @steps.map { |step| line(step, frame) }.join("\n") }
          end

          private

          def run_step(step, live)
            update(step, live) do
              step.status = :running
              step.started = now
            end
            step.value = step.block.call(Handle.new(step, live))
            finish(step, :done, live)
            nil
          rescue Skip => e
            step.note = e.message unless e.message == e.class.name
            finish(step, :skipped, live)
            nil
          rescue Exception => e # rubocop:disable Lint/RescueException -- ctrl+c and halt end the list too
            finish(step, e.is_a?(Halt) ? :done : :failed, live)
            e
          end

          def finish(step, status, live)
            update(step, live) do
              step.status = status
              step.finished = now if step.started
            end
            @shell.puts(line(step, 0)) unless live.running?
          end

          def update(step, live)
            @lock.synchronize { yield step }
            live.refresh
          end

          def line(step, frame)
            title = step.title
            detail = step.detail ? @shell.paint(" · #{step.detail}", :muted) : ""
            time = step.elapsed ? " #{@shell.paint(Tasks.duration(step.elapsed), :muted)}" : ""
            case step.status
            when :pending then "#{@shell.symbol(:pending)} #{@shell.paint(title, :pending)}"
            when :running then "#{@shell.paint(Live.spinner(frame), :running)} #{title}#{detail}"
            when :done then "#{@shell.symbol(:success)} #{title}#{detail}#{time}"
            when :failed then "#{@shell.symbol(:error)} #{title}#{detail}#{time}"
            when :skipped
              "#{@shell.symbol(:skipped)} #{@shell.paint("#{title} (#{step.note || "skipped"})", :skipped)}"
            end
          end

          def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        module_function

        # 0.12 → "120ms", 3.456 → "3.5s", 75 → "1m 15s".
        # Rounds before picking the unit, so 59.97 is "1m 0s", not "60.0s".
        def duration(seconds)
          return "#{(seconds * 1000).round}ms" if (seconds * 1000).round < 1000

          tenths = (seconds * 10).round
          return "#{format("%.1f", tenths / 10.0)}s" if tenths < 600

          total = seconds.round
          "#{total / 60}m #{total % 60}s"
        end

        # The list a `tasks` block is declaring on this thread (nil outside one).
        def collecting = Thread.current[:r2ui_cli_tasks]

        def collecting=(list)
          Thread.current[:r2ui_cli_tasks] = list
        end

        def running? = Thread.current[:r2ui_cli_tasks_running]

        # Runs the block as the thread's one running list (lists draw one region; they don't nest).
        def running
          raise Error, "steps can't run inside a running step" if running?

          Thread.current[:r2ui_cli_tasks_running] = true
          begin
            yield
          ensure
            Thread.current[:r2ui_cli_tasks_running] = nil
          end
        end
      end
    end

    extension :tasks do
      helpers do
        def tasks(&block)
          raise ArgumentError, "tasks needs a block" unless block
          raise Error, "tasks can't be nested" if Ext::Tasks.collecting

          list = Ext::Tasks::List.new(shell)
          begin
            Ext::Tasks.collecting = list
            block.call
          ensure
            Ext::Tasks.collecting = nil
          end
          Ext::Tasks.running { list.run }
        end

        def step(title, &block)
          if (list = Ext::Tasks.collecting)
            list.add(title, block)
            return nil
          end

          list = Ext::Tasks::List.new(shell)
          list.add(title, block)
          Ext::Tasks.running { list.run }.first
        end
      end
    end
  end
end
