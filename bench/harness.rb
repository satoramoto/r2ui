# frozen_string_literal: true

require "digest"
require "json"
require "stringio"
require_relative "fixtures"
require_relative "../conformance/lib/vt"

module Bench
  # Draws fixture frames stage by stage and measures each stage: time, allocated objects and the
  # bytes the compat renderer writes. Every frame's output is also fed to a VT emulator (outside
  # the timing), so a run records what the terminal showed; `screen` digests let a later run prove
  # an optimization left the screen unchanged.
  class Harness
    STAGES = %i[draw ansi output].freeze
    SCENARIOS = %i[steady animating data_change].freeze
    FRAME = 0.1 # seconds between frames while animating (agentmon draws motion at 10 fps)

    # A byte-counting stand-in for the terminal.
    class Sink
      attr_reader :bytes, :data

      def initialize
        @bytes = 0
        @data = +"".b
      end

      def write(str)
        @bytes += str.bytesize
        @data << str
        str.bytesize
      end

      def flush = self

      def take
        out = @data
        @data = +"".b
        @bytes = 0
        out
      end
    end

    attr_reader :app

    # `verify: false` skips the VT emulator (for profiling, where it would be noise).
    def initialize(fixture, width: WIDTH, height: HEIGHT, verify: true)
      @width = width
      @height = height
      @verify = verify
      @clock = Clock.new
      @world = World.new
      registry, = FIXTURES.fetch(fixture).call(@world)
      @app = R2UI::App.new(registry)
      @app.motion.clock = -> { @clock.now }
      @app.update(Bubbletea::WindowSizeMessage.new(width:, height:))
      @sink = Sink.new
      # The renderer options a dashboard runs with (R2UI::App::PROGRAM_OPTIONS).
      options = R2UI::App::PROGRAM_OPTIONS
      @renderer = R2UI::Compat::Tea::Renderer.new(@sink, synchronized: options[:synchronized] ? true : false,
                                                         line_diff: options[:line_diff] ? true : false)
      @renderer.set_size(width, height)
      @renderer.alt_screen = true
      @vt = Conformance::VT.new(cols: width, rows: height)
      @vt.feed("\e[?1049h")
      @screens = Digest::SHA256.new
      @views = Digest::SHA256.new
      refresh
      # History for the sparklines and motion state for the tables, as after a minute of running.
      60.times { tick! }
    end

    # Measures `frames` frames of `scenario` after `warmup` unmeasured ones (YJIT compiles early).
    # => { stage => { ms: [...], allocs: [...] }, bytes: [...], screens:, views: }
    def run(scenario, frames:, warmup:)
      warmup.times { |i| frame(scenario, i, measure: false) }
      @screens = Digest::SHA256.new
      @views = Digest::SHA256.new
      samples = STAGES.to_h { |s| [s, { ms: [], allocs: [] }] }
      samples[:bytes] = []
      frames.times do |i|
        result = frame(scenario, i, measure: true)
        STAGES.each do |s|
          samples[s][:ms] << result[s][0]
          samples[s][:allocs] << result[s][1]
        end
        samples[:bytes] << result[:bytes]
      end
      samples.merge(screens: @screens.hexdigest[0, 16], views: @views.hexdigest[0, 16])
    end

    # One measured frame of `scenario`; the setup that makes it that kind of frame is untimed.
    #   steady:      nothing changed since the last frame (an idle redraw).
    #   animating:   a sample arrived 1-3 frames ago; tweens, pulses and gutter marks are moving.
    #   data_change: a sample arrived since the last frame (feeds refreshed, Query re-runs).
    def frame(scenario, index, measure:)
      case scenario
      when :steady
        @clock.advance(FRAME)
      when :animating
        tick! if (index % 3).zero?
        @clock.advance(FRAME)
      when :data_change
        @clock.advance(1.0 - FRAME)
        @world.advance!
        refresh
        @clock.advance(FRAME)
      end
      draw(measure:)
    end

    # Draws one frame through the three stages, as App#view and the runner do.
    def draw(measure: true)
      result = {}
      canvas = stage(result, :draw) do
        @app.send(:seen_view)
        @app.frame(@width, @height)
      end
      view = stage(result, :ansi) { canvas.ansi_lines.join("\n") }
      stage(result, :output) { @renderer.render(view) }
      out = @sink.take
      result[:bytes] = out.bytesize
      return result unless @verify

      @vt.feed(out)
      if measure
        @screens << @vt.snapshot
        @views << view
      end
      result
    end

    # The terminal's screen after the last frame (VT snapshot text).
    def screen = @vt.snapshot

    private

    # A new sample, then the frame that shows it (untimed), then the motion settles for 3 s.
    def tick!
      @clock.advance(1.0)
      @world.advance!
      refresh
      draw(measure: false)
    end

    def refresh = @app.feeds.each_value(&:refresh!)

    def stage(result, name)
      a0 = GC.stat(:total_allocated_objects)
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      value = yield
      t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      a1 = GC.stat(:total_allocated_objects)
      result[name] = [(t1 - t0) * 1000.0, a1 - a0]
      value
    end
  end
end
