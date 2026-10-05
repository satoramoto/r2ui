# frozen_string_literal: true

# Where a frame's time and allocations go, for each fixture's steady, animating and data-change
# frames (bench/harness.rb, without the VT check).
#
#   bundle exec rake bench:profile                       # all fixtures and scenarios
#   ruby bench/profile.rb --only dense --scenario steady --frames 200 --yjit
#
# Prints stackprof's top frames by self time (CPU, wall-clock sampling) and by allocated objects,
# and writes a vernier profile per run to bench/results/profiles/<fixture>-<scenario>.json: open it
# at https://vernier.prof or https://profiler.firefox.com for the flame graph.

require "fileutils"
require "optparse"
require "stackprof"
require "vernier"
require_relative "harness"

opts = { frames: 150, warmup: 30, only: nil, scenario: nil, limit: 25 }
OptionParser.new do |o|
  o.on("--frames N", Integer) { |v| opts[:frames] = v }
  o.on("--only NAME") { |v| opts[:only] = v.to_sym }
  o.on("--scenario NAME") { |v| opts[:scenario] = v.to_sym }
  o.on("--limit N", Integer) { |v| opts[:limit] = v }
  o.on("--yjit") { RubyVM::YJIT.enable }
end.parse!(ARGV)

dir = File.expand_path("results/profiles", __dir__)
FileUtils.mkdir_p(dir)
fixtures = opts[:only] ? [opts[:only]] : Bench::FIXTURES.keys
scenarios = opts[:scenario] ? [opts[:scenario]] : Bench::Harness::SCENARIOS

fixtures.product(scenarios).each do |fixture, scenario|
  frames = ->(h) { opts[:frames].times { |i| h.frame(scenario, i, measure: true) } }
  harness = Bench::Harness.new(fixture, verify: false)
  opts[:warmup].times { |i| harness.frame(scenario, i, measure: false) }

  puts "\n=== #{fixture} #{scenario}: CPU (#{opts[:frames]} frames) ==="
  cpu = StackProf.run(mode: :cpu, interval: 200, raw: true) { frames.call(harness) }
  StackProf::Report.new(cpu).print_text(false, opts[:limit])

  puts "\n=== #{fixture} #{scenario}: allocated objects ==="
  objects = StackProf.run(mode: :object, interval: 1, raw: true) { frames.call(harness) }
  StackProf::Report.new(objects).print_text(false, opts[:limit])

  out = File.join(dir, "#{fixture}-#{scenario}.json")
  Vernier.profile(out:) { frames.call(harness) }
  puts "flame graph: #{out}"
end
