# frozen_string_literal: true

require "r2ui"

# Two dashboards shaped like agentmon's `--layout dense` and `--layout visual` (the r2ui consumer
# this bench stands in for), on fixed data and a simulated clock: wide tables of ~60 rows with
# braille sparklines and heat-coloured 24-bit cells and motion gutters, plus panel items drawn as
# ANSI strings (meters, braille sparks and areas, stat grids) the way agentmon draws them.
# Nothing here reads the machine or the wall clock, so every run draws the same frames.
module Bench
  WIDTH = 100
  HEIGHT = 50
  G = R2UI::Widgets::Glyphs

  # The simulated clock behind every fixture's Motion.
  class Clock
    attr_accessor :now

    def initialize = @now = 1000.0
    def advance(seconds) = @now += seconds
  end

  Proc = Data.define(:pid, :name, :session, :cpu, :footprint, :run_wait, :pagein_rate, :read_rate, :write_rate)
  Session = Data.define(:sid, :label, :processes, :cpu, :footprint, :age)

  NAMES = ["Claude Helper", "Claude Helper (Renderer)", "Codex (Renderer)", "Codex (Service)", "claude", "node",
           "zsh", "cargo", "rustc", "ruby", "bare-modifier-monitor", "git", "rg", "agentmon --layout dense"].freeze
  SESSIONS = ["Claude 21354", "ChatGPT 2388", "claude 22602 · agentmon", "claude 22034 · agentmon",
              "claude 26329 · funkadelic-astronaut-web", "codex 3064 · Resources", "codex 2903", "claude 4242 · r2ui"].freeze

  # name => [unit, max, typical]
  SIGNALS = {
    cpu: [:percent, 100.0, 30.0], user: [:percent, 100.0, 18.0], load1: [:number, nil, 4.5],
    load5: [:number, nil, 4.0], load15: [:number, nil, 3.8], ncpu: [:integer, nil, 10],
    used: [:bytes, 32.0 * (1024**3), 22.0 * (1024**3)], pressure: [:percent, 100.0, 30.0],
    swap: [:bytes, 2.0 * (1024**3), 0.3 * (1024**3)], compressed: [:bytes, nil, 5.5 * (1024**3)],
    app: [:bytes, nil, 14.0 * (1024**3)], wired: [:bytes, nil, 3.2 * (1024**3)], cached: [:bytes, nil, 7.7 * (1024**3)],
    net_in: [:bytes_per_sec, nil, 4096.0], net_out: [:bytes_per_sec, nil, 3000.0],
    disk_rd: [:bytes_per_sec, nil, 200_000.0], disk_wr: [:bytes_per_sec, nil, 50_000.0],
    session_cpu: [:percent, nil, 35.0], session_footprint: [:bytes, nil, 5.4 * (1024**3)]
  }.freeze
  LABELS = { cpu: "CPU", user: "user", load1: "load 1m", load5: "load 5m", load15: "load 15m", ncpu: "cores",
             used: "used", pressure: "pressure", swap: "swap", compressed: "compr", app: "app", wired: "wired",
             cached: "cached", net_in: "net in", net_out: "net out", disk_rd: "disk rd", disk_wr: "disk wr",
             session_cpu: "CPU", session_footprint: "footprint" }.freeze

  # Machine readings at each tick (one tick per sample): a pure function of (seed, tick).
  class World
    PROCESSES = 60
    HISTORY = 240

    attr_reader :tick

    def initialize(seed: 7)
      @seed = seed
      @tick = 0
      base = Random.new(seed)
      @base = Array.new(PROCESSES) { (base.rand**3) * 60 }
      @mem = Array.new(PROCESSES) { (base.rand**2) * 900 * (1024**2) }
      @series = {}
    end

    def advance!
      @tick += 1
      @processes = @sessions = nil
      @series.clear
    end

    def processes
      @processes ||= begin
        rng = Random.new((@seed * 100_003) + @tick)
        Array.new(PROCESSES) do |i|
          Proc.new(pid: 2000 + (i * 37), name: NAMES[i % NAMES.size], session: SESSIONS[i % SESSIONS.size],
                   cpu: (@base[i] * (0.4 + (rng.rand * 1.2))).round(1), footprint: (@mem[i] * (0.9 + (rng.rand * 0.2))).round,
                   run_wait: (rng.rand * 4).round(1), pagein_rate: (rng.rand * 2).round(1),
                   read_rate: i % 5 == 0 ? (rng.rand * 80_000).round : 0, write_rate: i % 7 == 0 ? (rng.rand * 40_000).round : 0)
        end
      end
    end

    def sessions
      @sessions ||= processes.group_by(&:session).each_with_index.map do |(label, procs), i|
        Session.new(sid: i, label:, processes: procs.size, cpu: procs.sum(&:cpu).round(1), footprint: procs.sum(&:footprint),
                    age: 600 + (i * 3700) + @tick)
      end
    end

    def value(name) = series(name).last

    # The last HISTORY samples of a signal, newest last.
    def series(name)
      @series[name] ||= begin
        _, max, typical = SIGNALS.fetch(name)
        ((@tick - HISTORY + 1)..@tick).map { |t| sample(name, t, max, typical) }
      end
    end

    private

    def sample(name, tick, max, typical)
      return typical if name == :ncpu

      wave = Math.sin((tick / 9.0) + name.hash.abs % 7) * 0.35
      noise = Random.new((@seed * 7919) + (tick * 31) + SIGNALS.keys.index(name)).rand * 0.3
      v = typical * (1 + wave + noise - 0.15)
      max ? v.clamp(0, max) : [v, 0].max
    end
  end

  # The ANSI drawing agentmon's views do (lib/agentmon/views/widgets.rb there), trimmed: Strings
  # in, Strings out, every line exactly `width` cells.
  module Paint
    ACCENT = "#D97757"
    DIM = "#555555"
    TROUGH = "#303030"
    MUTED = "#8A8A8A"
    PULSE = "#FFE0C2"
    SGR = /\e\[[0-9;?]*[ -\/]*[@-~]/

    module_function

    def visible_width(str) = R2UI::Compat::Tea::ANSI.string_width(str.to_s.gsub(SGR, ""))

    def pad(str, width, align: :left)
      gap = width - visible_width(str)
      return str if gap <= 0

      align == :right ? (" " * gap) + str : str + (" " * gap)
    end

    def fit(str, width) = pad(visible_width(str) > width ? R2UI::Compat::Tea::ANSI.truncate(str, width) : str, width)

    def text(unit, value) = R2UI::Format.call(unit == :integer ? :number : unit, value)

    def value_sgr(unit, fraction, pulse)
      base = if unit == :percent && fraction then G.gradient(G::HEAT, fraction.clamp(0.0, 1.0))
             elsif %i[bytes bytes_per_sec].include?(unit) then ACCENT
             end
      return base && G.fg(base) unless pulse.positive?

      sgr = G.fg(R2UI::Motion.mix_hex(base || "#BCBCBC", PULSE, pulse))
      pulse > 0.3 ? "#{sgr};1" : sgr
    end

    def sides(left, left_sgr, right, right_sgr, width)
      gap = [width - visible_width(left) - visible_width(right), 1].max
      fit(G.paint(left, left_sgr) + (" " * gap) + G.paint(right, right_sgr), width)
    end

    def meter(label, label_w, text, text_w, fraction, width, text_sgr)
      bw = width - label_w - text_w - 4
      bar = G.paint(G.bar(fraction, bw), "#{G.heat(fraction)};#{G.bg(TROUGH)}")
      fit(pad(label, label_w) + " " + G.paint("▕", G.fg(DIM)) + bar + G.paint("▏", G.fg(DIM)) + " " +
          pad(G.paint(text, text_sgr), text_w, align: :right), width)
    end

    def spark(label, label_w, values, max, text, text_w, width, text_sgr)
      sw = width - label_w - text_w - 2
      chart = G.paint(G.braille_line(values, sw, max:), G.fg(ACCENT))
      fit(pad(label, label_w) + " " + chart + " " + pad(G.paint(text, text_sgr), text_w, align: :right), width)
    end

    def area(values, width, height, max, sgr) = G.braille_area(values, width, height, max:).map { |row| G.paint(row, sgr) }
  end

  # Panel items drawn by the `bench` extension: kind is :meter, :spark, :trend, :stat or :detail.
  Item = Data.define(:kind, :signals, :options)

  # Per-app drawing state, like agentmon's view runtime: last texts (for pulses) and a string cache
  # (agentmon caches drawn strings by what they show, so a frame redraws only what changed).
  class Runtime
    CACHE_LIMIT = 2000

    attr_reader :world

    def initialize(world)
      @world = world
      @shown = {}
      @cache = {}
    end

    def pulse(motion, key, text)
      before = @shown[key]
      @shown[key] = text
      level = motion.pulse(key, !before.nil? && before != text, duration: 0.5)
      (level * 12).round / 12.0
    end

    def cached(key)
      @cache.clear if @cache.size > CACHE_LIMIT
      @cache.fetch(key) { @cache[key] = yield }
    end
  end

  module Draw
    module_function

    def label_width(panel) = panel.items.grep(Item).flat_map(&:signals).map { |s| LABELS[s].length }.max

    def call(ctx, rt, item)
      send(item.kind, ctx, rt, item)
    end

    def meter(ctx, rt, item)
      sig = item.signals.first
      unit, max, = SIGNALS[sig]
      value = rt.world.value(sig)
      fraction = value / max
      text = Paint.text(unit, value)
      shown = ctx.motion.tween([:meter, ctx.panel.name, sig], fraction, duration: 0.35)
      pulse = rt.pulse(ctx.motion, [:pulse, ctx.panel.name, sig], text)
      width = ctx.width
      steps = (shown * width * 8).round
      rt.cached([:meter, sig, width, steps, text, pulse]) do
        Paint.meter(LABELS[sig], label_width(ctx.panel), text, 9, shown, width, Paint.value_sgr(unit, fraction, pulse))
      end
    end

    def spark(ctx, rt, item)
      sig = item.signals.first
      unit, max, = SIGNALS[sig]
      value = rt.world.value(sig)
      text = Paint.text(unit, value)
      pulse = rt.pulse(ctx.motion, [:pulse, ctx.panel.name, sig], text)
      values = rt.world.series(sig)
      rt.cached([:spark, sig, ctx.width, values.hash, pulse]) do
        Paint.spark(LABELS[sig], label_width(ctx.panel), values, max, text, 6, ctx.width,
                    Paint.value_sgr(unit, max && value / max, pulse))
      end
    end

    def trend(ctx, rt, item)
      sigs = item.signals
      room = [(item.options[:height] || (ctx.height - sigs.size)), sigs.size].max
      share, extra = room.divmod(sigs.size)
      sigs.each_with_index.flat_map do |sig, i|
        unit, max, = SIGNALS[sig]
        values = rt.world.series(sig)
        value = values.last
        text = Paint.text(unit, value)
        pulse = rt.pulse(ctx.motion, [:pulse, ctx.panel.name, sig], text)
        height = share + (i < extra ? 1 : 0)
        header = rt.cached([:trend_head, sig, ctx.width, text, pulse]) do
          Paint.sides(item.options[:label] || LABELS[sig], G.fg(Paint::MUTED), text, Paint.value_sgr(unit, max && value / max, pulse),
                      ctx.width)
        end
        sgr = max ? G.heat(value / max) : G.fg(Paint::ACCENT)
        area = rt.cached([:trend_area, sig, ctx.width, height, values.hash]) do
          Paint.area(values, ctx.width, height, max, sgr)
        end
        [header, *area]
      end.join("\n")
    end

    def stat(ctx, rt, item)
      columns = item.options[:columns] || 2
      cell_w = (ctx.width - (2 * (columns - 1))) / columns
      cells = item.signals.map do |sig|
        unit, max, = SIGNALS[sig]
        value = rt.world.value(sig)
        text = Paint.text(unit, value)
        pulse = rt.pulse(ctx.motion, [:pulse, ctx.panel.name, sig], text)
        rt.cached([:stat, sig, cell_w, text, pulse]) do
          Paint.sides(LABELS[sig], G.fg(Paint::MUTED), text, Paint.value_sgr(unit, max && value / max, pulse), cell_w)
        end
      end
      cells.each_slice(columns).map { |row| Paint.fit(row.join("  "), ctx.width) }.join("\n")
    end

    # A three-column key/value grid about the busiest process.
    def detail(ctx, rt, _item)
      top = rt.world.processes.max_by(&:cpu)
      pairs = [["Command", "/Applications/#{top.name}.app/Contents/MacOS/#{top.name}"], ["Resident", R2UI::Format.bytes(top.footprint)],
               ["Started", "#{rt.world.tick}s ago"], ["Directory", "/"], ["Peak", R2UI::Format.bytes(top.footprint * 2)],
               ["Open files", "16"], ["Session", top.session], ["CPU", format("%.1f%%", top.cpu)], ["Threads", "19"],
               ["Footprint", R2UI::Format.bytes(top.footprint)], ["Written", "192K"], ["Wait", "#{top.run_wait}%"]]
      cell_w = (ctx.width - 4) / 3
      head = G.paint("#{top.name}  pid #{top.pid}", "1")
      rows = pairs.each_slice(3).map do |row|
        Paint.fit(row.map { |k, v| Paint.fit(G.paint(k.ljust(10), G.fg(Paint::MUTED)) + " " + v, cell_w) }.join("  "), ctx.width)
      end
      [Paint.fit(head, ctx.width), *rows].join("\n")
    end
  end

  R2UI.extension :bench do
    dsl :panel do
      def bench(kind, *signals, **options) = item(Bench::Item.new(kind:, signals:, options:))
    end
    dsl :dashboard do
      def bench_runtime(runtime) = declare(:bench_runtime, runtime)
    end
    panel_item(Bench::Item) { |item| Bench::Draw.call(self, dashboard.declared(:bench_runtime).first, item) }
  end

  module_function

  def heat = ->(value, _line) { value.is_a?(Numeric) ? G.heat(value / 100.0) : nil }
  def accent = ->(value, _line) { value.is_a?(Numeric) ? G.fg(Paint::ACCENT) : nil }

  def process_resource(world, name_width:, session_width:)
    R2UI::DSL::Resource.build(:process) do
      title "Processes"
      source { world.processes }
      key :pid
      scope :agents, label: "Agents", default: true
      scope :all
      %i[busy heavy writing waiting].each { |s| scope(s) { |p| p.cpu >= 0 } }
      group_by :session
      index do
        column :pid, format: :id, priority: 4
        column :name, width: name_width, priority: 9
        column :session, width: session_width, priority: 8
        column :cpu, label: "CPU", format: :percent, sort: :desc, sparkline: :braille, spark_width: 5, spark_max: 100,
                     style: Bench.heat, spark_style: ->(values, _line) { G.heat((values.last || 0) / 100.0) }, priority: 9
        column :footprint, format: :bytes, style: Bench.accent, priority: 8
        column :run_wait, label: "Wait", format: :percent, style: Bench.heat, priority: 3
        column :pagein_rate, label: "Pgin/s", format: :number, priority: 2
        column :read_rate, label: "Read", format: :bytes_per_sec, style: Bench.accent, priority: 2
        column :write_rate, label: "Write", format: :bytes_per_sec, style: Bench.accent, priority: 2
      end
    end
  end

  def session_resource(world, label_width:)
    R2UI::DSL::Resource.build(:session) do
      title "Sessions"
      source { world.sessions }
      key :sid
      scope :live, label: "Live", default: true
      scope :all
      index do
        column :label, label: "Session", width: label_width, priority: 9
        column :processes, label: "Procs", format: :integer, priority: 6
        column :cpu, label: "CPU", format: :percent, sort: :desc, sparkline: :braille, spark_width: 5, spark_max: 100,
                     style: Bench.heat, spark_style: ->(values, _line) { G.heat((values.last || 0) / 100.0) }, priority: 9
        column :footprint, format: :bytes, style: Bench.accent, priority: 8
        column(:age, label: "Age", width: 7, priority: 5) { |s| "#{s.age / 3600}h #{(s.age % 3600) / 60}m" }
      end
    end
  end

  # => [registry, runtime]
  def dense(world)
    runtime = Runtime.new(world)
    registry = R2UI::Registry.new
    registry.add_resource(process_resource(world, name_width: 19, session_width: 16))
    registry.add_resource(session_resource(world, label_width: 54))
    registry.add_dashboard(R2UI::DSL::Dashboard.build(:main) do
      title "bench dense"
      bench_runtime runtime
      row height: 6 do
        panel :cpu, resource: nil, title: "CPU", span: 3 do
          bench :spark, :cpu
          bench :spark, :user
          bench :stat, :load1, :load5, :load15, :ncpu, columns: 2
        end
        panel :memory, resource: nil, title: "Memory", span: 2 do
          %i[used pressure swap compressed].each { |s| bench :spark, s }
        end
        panel :io, resource: nil, title: "I/O", span: 2 do
          %i[net_in net_out disk_rd disk_wr].each { |s| bench :spark, s }
        end
      end
      row height: 9 do
        panel :session, title: "Sessions" do
          table sort: %i[cpu desc], columns: %i[label processes cpu footprint age], motion: true
        end
      end
      row do
        panel :process, title: "Processes" do
          table sort: %i[cpu desc], columns: %i[pid name session cpu footprint run_wait pagein_rate read_rate write_rate],
                motion: true
        end
      end
      row height: 7 do
        panel :detail, resource: nil, title: "Detail" do
          bench :detail
        end
      end
    end)
    [registry, runtime]
  end

  def visual(world)
    runtime = Runtime.new(world)
    registry = R2UI::Registry.new
    registry.add_resource(process_resource(world, name_width: 16, session_width: 14))
    registry.add_resource(session_resource(world, label_width: 16))
    registry.add_dashboard(R2UI::DSL::Dashboard.build(:main) do
      title "bench visual"
      bench_runtime runtime
      row height: 11 do
        panel :cpu, resource: nil, title: "CPU" do
          bench :meter, :cpu
          bench :trend, :cpu, height: 6, label: "last 4 min"
          bench :stat, :load1, :load5, :load15, columns: 3
        end
        panel :memory, resource: nil, title: "Memory" do
          bench :meter, :used
          bench :meter, :pressure
          bench :meter, :swap
          bench :stat, :app, :wired, :compressed, :cached, columns: 2
          bench :trend, :used, label: "used, last 4 min"
        end
      end
      row height: 9 do
        panel(:network, resource: nil, title: "Network") { bench :trend, :net_in, :net_out }
        panel(:disk, resource: nil, title: "Disk") { bench :trend, :disk_rd, :disk_wr }
      end
      row do
        panel :process, title: "Processes", span: 3 do
          table sort: %i[cpu desc], columns: %i[name session cpu footprint], motion: true
        end
        panel :session, title: "Sessions", span: 2 do
          bench :trend, :session_cpu, height: 7
          bench :trend, :session_footprint, height: 7
          table sort: %i[cpu desc], columns: %i[label cpu footprint], motion: true
        end
      end
    end)
    [registry, runtime]
  end

  FIXTURES = { dense: method(:dense), visual: method(:visual) }.freeze
end
