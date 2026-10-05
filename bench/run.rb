# frozen_string_literal: true

# Per-frame cost of drawing the bench fixtures (bench/fixtures.rb), by stage, YJIT off and on.
#
#   bundle exec rake bench                  # table + delta against bench/results/baseline.json
#   bundle exec rake bench:baseline         # the same, then saves this run as the baseline
#   ruby bench/run.rb --frames 60           # options: --frames N, --warmup N, --only dense
#
# Each YJIT mode runs in its own child process (`ruby [--yjit] bench/run.rb --child`), which
# prints its summary as JSON. Results: bench/results/latest.json (and baseline.json).

require "json"
require "optparse"
require "rbconfig"

module Bench
  module Run
    RESULTS = File.expand_path("results", __dir__)
    BASELINE = File.join(RESULTS, "baseline.json")
    LATEST = File.join(RESULTS, "latest.json")
    MODES = { "off" => [], "on" => ["--yjit"] }.freeze

    module_function

    def main(argv)
      opts = { frames: 60, warmup: 30, only: nil, child: false, save: false }
      OptionParser.new do |o|
        o.on("--frames N", Integer) { |v| opts[:frames] = v }
        o.on("--warmup N", Integer) { |v| opts[:warmup] = v }
        o.on("--only NAME") { |v| opts[:only] = v.to_sym }
        o.on("--child") { opts[:child] = true }
        o.on("--save-baseline") { opts[:save] = true }
      end.parse!(argv)
      opts[:child] ? child(opts) : parent(opts)
    end

    # --- child: measure in this process ---

    def child(opts)
      require_relative "harness"
      fixtures = opts[:only] ? [opts[:only]] : FIXTURES.keys
      results = fixtures.to_h do |fixture|
        [fixture, Harness::SCENARIOS.to_h do |scenario|
          GC.start
          samples = Harness.new(fixture).run(scenario, frames: opts[:frames], warmup: opts[:warmup])
          [scenario, summarize(samples)]
        end]
      end
      puts JSON.generate(yjit: defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? true : false, results:)
    end

    def summarize(samples)
      stages = Harness::STAGES.to_h do |s|
        ms = samples[s][:ms]
        [s, { ms_median: median(ms), ms_p95: pct(ms, 0.95), allocs: median(samples[s][:allocs]) }]
      end
      totals = samples[Harness::STAGES.first][:ms].each_index.map { |i| Harness::STAGES.sum { |s| samples[s][:ms][i] } }
      allocs = samples[Harness::STAGES.first][:allocs].each_index.map { |i| Harness::STAGES.sum { |s| samples[s][:allocs][i] } }
      { stages:, total: { ms_median: median(totals), ms_p95: pct(totals, 0.95), allocs: median(allocs) },
        bytes: { median: median(samples[:bytes]), mean: (samples[:bytes].sum.to_f / samples[:bytes].size).round },
        screens: samples[:screens], views: samples[:views] }
    end

    def median(list) = pct(list, 0.5)

    def pct(list, q)
      sorted = list.sort
      sorted[[(q * sorted.size).ceil - 1, 0].max].round(3)
    end

    # --- parent: run both YJIT modes, print, compare, save ---

    def parent(opts)
      args = ["--child", "--frames", opts[:frames].to_s, "--warmup", opts[:warmup].to_s]
      args += ["--only", opts[:only].to_s] if opts[:only]
      run = { ruby: RUBY_DESCRIPTION, at: Time.now.utc.iso8601, frames: opts[:frames], warmup: opts[:warmup], modes: {} }
      MODES.each do |mode, flags|
        out = IO.popen([RbConfig.ruby, *flags, __FILE__, *args], &:read)
        raise "bench child (yjit #{mode}) failed" unless $?.success?

        run[:modes][mode] = JSON.parse(out)["results"]
      end
      run = JSON.parse(JSON.generate(run)) # string keys, as when loaded
      baseline = File.exist?(BASELINE) ? JSON.parse(File.read(BASELINE)) : nil
      print_run(run, baseline)
      Dir.mkdir(RESULTS) unless Dir.exist?(RESULTS)
      File.write(LATEST, JSON.pretty_generate(run))
      File.write(BASELINE, JSON.pretty_generate(run)) if opts[:save]
      puts "\nsaved #{relative(LATEST)}#{opts[:save] ? " and #{relative(BASELINE)}" : ""}"
    end

    def relative(path) = path.delete_prefix("#{File.expand_path("..", __dir__)}/")

    def print_run(run, baseline)
      run["modes"].each do |mode, fixtures|
        puts "\nYJIT #{mode} (ms per frame: median, p95 of the total; allocs = objects; bytes written)"
        puts format("%-22s %8s %8s %8s %9s %8s %8s %8s %8s  %s", "frame", "draw", "ansi", "output", "total",
                    "p95", "allocs", "bytes", "Δtotal", "screen")
        fixtures.each do |fixture, scenarios|
          scenarios.each do |scenario, r|
            base = baseline&.dig("modes", mode, fixture, scenario)
            st = r["stages"]
            delta = base ? format("%+.0f%%", ((r["total"]["ms_median"] / base["total"]["ms_median"]) - 1) * 100) : "-"
            screen = if base.nil? then "-"
                     elsif base["screens"] == r["screens"] then "same"
                     else "DIFFERS"
                     end
            puts format("%-22s %8.2f %8.2f %8.2f %9.2f %8.2f %8d %8d %8s  %s", "#{fixture} #{scenario}",
                        st["draw"]["ms_median"], st["ansi"]["ms_median"], st["output"]["ms_median"],
                        r["total"]["ms_median"], r["total"]["ms_p95"], r["total"]["allocs"], r["bytes"]["median"],
                        delta, screen)
          end
        end
        print_allocs(fixtures, baseline&.dig("modes", mode))
      end
    end

    # Allocations and bytes per stage, with the baseline's in brackets.
    def print_allocs(fixtures, base)
      puts format("%-22s %16s %16s %16s %18s", "allocs by stage", "draw", "ansi", "output", "bytes (mean)")
      fixtures.each do |fixture, scenarios|
        scenarios.each do |scenario, r|
          b = base&.dig(fixture, scenario)
          cells = %w[draw ansi output].map do |s|
            now = r["stages"][s]["allocs"].to_i
            b ? "#{now} [#{b["stages"][s]["allocs"].to_i}]" : now.to_s
          end
          bytes = b ? "#{r["bytes"]["mean"]} [#{b["bytes"]["mean"]}]" : r["bytes"]["mean"].to_s
          puts format("%-22s %16s %16s %16s %18s", "#{fixture} #{scenario}", *cells, bytes)
        end
      end
    end
  end
end

require "time"
Bench::Run.main(ARGV) if $PROGRAM_NAME == __FILE__
