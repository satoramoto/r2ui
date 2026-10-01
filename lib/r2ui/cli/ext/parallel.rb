# frozen_string_literal: true

# c13-parallel: concurrent jobs with live status, like `pnpm -r` or turbo. Each job has one status
# line: queued, spinning while it runs, then ✔ / ✖ with its timing.
#
#   results = parallel(max: 4) do
#     job("api") { build_api }                                  # the block's value is kept
#     job("web") { |j| bundle { |n| j.detail = "#{n} modules" } }
#     job("docs") { build_docs }
#   end                                                         # => { "api" => ..., "web" => ..., "docs" => ... }
#
# On a terminal (Shell#live?) every job's line is redrawn together:
#
#   ✔ api 1.2s
#   ⠹ web · 412 modules
#   ○ docs
#
# and the final lines stay in the scrollback. When there are more jobs than the terminal has rows,
# finished jobs print above the region as they end and the region shows only the running jobs and
# how many are queued. Off a terminal each job prints one line when it ends, in the order they end
# ("✔ api 1.2s", "✖ web · Module not found 0.4s"): no spinner frames, no escape codes.
#
# The `parallel` block declares the jobs; they run after it on up to `max` threads (default 4,
# pnpm's), started in declaration order. A job's block runs on its own thread but sees the same
# `args`, `options` and helpers; `say` inside a job prints above the lines. `j.detail = "..."` and
# `j.title = "..."` change its line while it runs.
#
# A job that raises shows ✖ with the error's message; the other jobs carry on. When every job has
# ended, `parallel` raises a `CLI::Error` naming the failed jobs, with the first error to happen as
# its `cause` (a command exits 1 with "✖ 2 jobs failed: web, docs"). Ctrl+c, `halt` or `exit`
# inside a job stops the rest at once: running and queued jobs show "– name (cancelled)" and the
# interrupt propagates (exit 130 for ctrl+c). Otherwise it returns the jobs' values as a Hash by
# job name, in declaration order.
#
# Jobs don't nest: `parallel` inside a job raises. Don't start `tasks`, `spin` or another live
# helper inside a job either; there is one live region at a time.
require "monitor"

module R2UI
  module CLI
    module Ext
      module Parallel
        DEFAULT_MAX = 4

        # Raised when jobs failed; `failures` maps each failed job's name to its error.
        class Failed < Error
          attr_reader :failures

          def initialize(failures)
            @failures = failures
            names = failures.keys.map(&:to_s)
            super(names.one? ? "job #{names.first} failed: #{failures.values.first.message}" : "#{names.size} jobs failed: #{names.join(", ")}")
          end
        end

        Job = Struct.new(:name, :title, :block, :status, :detail, :started, :finished, :value, :error) do
          def elapsed = finished && started ? finished - started : nil
        end

        # What a job's block gets: change its title or detail while it runs.
        class Handle
          def initialize(job, pool)
            @job = job
            @pool = pool
          end

          def name = @job.name

          def title = @job.title

          def title=(text)
            @pool.change { @job.title = text.to_s }
          end

          def detail=(text)
            @pool.change { @job.detail = text&.to_s }
          end
        end

        # The jobs a `parallel` block declared, and how they run and draw.
        class Pool
          def initialize(shell, max)
            @shell = shell
            @max = max
            @jobs = []
            @lock = Monitor.new
            @live = nil
          end

          def add(name, block)
            raise ArgumentError, "job needs a block" unless block
            raise ArgumentError, "job #{name} is declared twice" if @jobs.any? { |j| j.name.to_s == name.to_s }

            @jobs << Job.new(name:, title: name.to_s, block:, status: :queued)
          end

          # Runs every job; returns { name => value }. Raises Failed after all end if any failed.
          def run
            return {} if @jobs.empty?

            @live = Live.new(@shell) { |frame| view(frame) }
            @compact = @live.live? && @jobs.size > @shell.height - 1
            @live.clear = @compact # every result is already printed above the region
            @live.run { run_jobs }
            failed = @jobs.select { |j| j.status == :failed }
            unless failed.empty?
              first = failed.min_by(&:finished).error
              raise Failed.new(failed.to_h { |j| [j.name, j.error] }), cause: first
            end
            @jobs.to_h { |j| [j.name, j.value] }
          end

          # Updates a job's state, then redraws (never while holding the lock: the Live ticker
          # takes its own lock and then calls `view`).
          def change(&)
            @lock.synchronize(&)
            @live&.refresh
            nil
          end

          def view(frame)
            @lock.synchronize do
              return compact_view(frame) if @compact

              @jobs.map { |job| line(job, frame) }.join("\n")
            end
          end

          private

          def run_jobs
            queue = Queue.new
            @jobs.each { |job| queue << job }
            queue.close
            events = Queue.new
            workers = Array.new([@max, @jobs.size].min) do
              Thread.new do
                Thread.current.report_on_exception = false
                Thread.current[:r2ui_cli_parallel_job] = true
                while (job = queue.pop)
                  fatal = run_job(job)
                  events << (fatal ? [:fatal, fatal] : [:done, job])
                  break if fatal
                end
              end
            end
            ended = 0
            while ended < @jobs.size
              kind, value = events.pop
              raise value if kind == :fatal

              ended += 1
            end
          ensure
            stop(workers) if workers
          end

          # Runs one job; returns an exception that must stop every job (ctrl+c, halt, exit).
          def run_job(job)
            change do
              job.status = :running
              job.started = now
            end
            value = job.block.call(Handle.new(job, self))
            finish(job, :done) { job.value = value }
            nil
          rescue StandardError => e
            finish(job, :failed) { job.error = e }
            nil
          rescue Exception => e # rubocop:disable Lint/RescueException -- ctrl+c, halt and exit stop the pool
            finish(job, e.is_a?(Halt) ? :done : :failed) { job.error = e }
            e
          end

          # Kills jobs still running (after ctrl+c or a fatal job) and marks the unfinished ones
          # cancelled.
          def stop(workers)
            workers.each(&:kill)
            workers.each { |w| w.join(5) }
            @jobs.each { |job| finish(job, :cancelled) if %i[queued running].include?(job.status) }
          end

          def finish(job, status)
            text = nil
            change do
              yield if block_given?
              job.status = status
              job.finished = now if job.started
              text = line(job, 0) if !@live.running? || @compact
            end
            @shell.puts(text) if text
          end

          def compact_view(frame)
            running = @jobs.select { |j| j.status == :running }
            queued = @jobs.count { |j| j.status == :queued }
            lines = running.first([@shell.height - 2, 1].max).map { |job| line(job, frame) }
            more = running.size - lines.size
            notes = []
            notes << "#{more} more running" if more.positive?
            notes << "#{queued} queued" if queued.positive?
            lines << "#{@shell.symbol(:pending)} #{@shell.paint(notes.join(" · "), :pending)}" unless notes.empty?
            lines.join("\n")
          end

          def line(job, frame)
            title = job.title
            detail = job.error.is_a?(StandardError) ? job.error.message.lines.first.to_s.chomp : job.detail
            detail = detail && !detail.empty? ? @shell.paint(" · #{detail}", :muted) : ""
            time = job.elapsed ? " #{@shell.paint(Parallel.duration(job.elapsed), :muted)}" : ""
            case job.status
            when :queued then "#{@shell.symbol(:pending)} #{@shell.paint(title, :pending)}"
            when :running then "#{@shell.paint(Live.spinner(frame), :running)} #{title}#{detail}"
            when :done then "#{@shell.symbol(:success)} #{title}#{detail}#{time}"
            when :failed then "#{@shell.symbol(:error)} #{title}#{detail}#{time}"
            when :cancelled then "#{@shell.symbol(:skipped)} #{@shell.paint("#{title} (cancelled)", :skipped)}"
            end
          end

          def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        module_function

        # 0.12 → "120ms", 3.456 → "3.5s", 75 → "1m 15s" (the task list's format).
        def duration(seconds)
          return "#{(seconds * 1000).round}ms" if (seconds * 1000).round < 1000

          tenths = (seconds * 10).round
          return "#{format("%.1f", tenths / 10.0)}s" if tenths < 600

          total = seconds.round
          "#{total / 60}m #{total % 60}s"
        end

        # The pool a `parallel` block is declaring on this thread (nil outside one).
        def collecting = Thread.current[:r2ui_cli_parallel]

        def collecting=(pool)
          Thread.current[:r2ui_cli_parallel] = pool
        end

        def in_job? = Thread.current[:r2ui_cli_parallel_job]
      end
    end

    extension :parallel do
      helpers do
        def parallel(max: Ext::Parallel::DEFAULT_MAX, &block)
          raise ArgumentError, "parallel needs a block" unless block
          raise ArgumentError, "max must be a positive Integer, not #{max.inspect}" unless max.is_a?(Integer) && max.positive?
          raise Error, "parallel can't be nested" if Ext::Parallel.collecting || Ext::Parallel.in_job?

          pool = Ext::Parallel::Pool.new(shell, max)
          begin
            Ext::Parallel.collecting = pool
            block.call
          ensure
            Ext::Parallel.collecting = nil
          end
          pool.run
        end

        def job(name, &block)
          pool = Ext::Parallel.collecting
          raise Error, "job #{name} must be declared inside a parallel block" unless pool

          pool.add(name, block)
          nil
        end
      end
    end
  end
end
