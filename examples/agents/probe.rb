# frozen_string_literal: true

require "set"

# macOS data for the agents dashboard: processes (with working directory and owning agent) and memory.
module AgentProbe
  # Command-line agents: each process is one session.
  CLI = /\A(claude|codex)\z/
  # Desktop apps that run agents; all their helpers count as one session.
  APP = /claude|codex|chatgpt/i
  CWD_TTL = 5

  Proc = Data.define(:pid, :ppid, :name, :command, :cpu, :rss, :cwd, :agent)

  Memory = Data.define(
    :total, :used, :app, :wired, :compressed, :compression_ratio, :cached, :free,
    :swap_used, :swap_total, :pressure, :swapouts_per_sec, :compressions_per_sec
  )

  module_function

  def processes
    raw = `ps -axo pid=,ppid=,pcpu=,rss=,comm=`.lines.filter_map do |line|
      pid, ppid, cpu, rss, command = line.strip.split(nil, 5)
      next unless command

      { pid: pid.to_i, ppid: ppid.to_i, cpu: cpu.to_f, rss: rss.to_i * 1024, command: }
    end
    by_pid = raw.to_h { |r| [r[:pid], r] }
    cwds = cwd_cache
    raw.map do |r|
      name = File.basename(r[:command])
      Proc.new(**r, name:, cwd: cwds[r[:pid]], agent: agent_for(r, by_pid, cwds))
    end
  end

  # The session a process belongs to: its outermost claude/codex CLI ancestor ("claude 4242 · yahaha"),
  # else the topmost agent app ("ChatGPT 401"). Shells, tools and sub-agents count toward it.
  def agent_for(row, by_pid, cwds)
    cli = app = nil
    seen = Set.new
    while row && seen.add?(row[:pid])
      name = File.basename(row[:command])
      cli = row if name.match?(CLI)
      app = row if name.match?(APP)
      row = by_pid[row[:ppid]]
    end
    return "#{File.basename(app[:command])} #{app[:pid]}" if app && !cli

    cli && session_label(cli, cwds)
  end

  def session_label(row, cwds)
    name = File.basename(row[:command])
    dir = cwds[row[:pid]]
    dir && dir != "/" ? "#{name} #{row[:pid]} · #{File.basename(dir)}" : "#{name} #{row[:pid]}"
  end

  # lsof takes ~0.4s for every process, so working directories refresh every few seconds.
  def cwd_cache
    return @cwds if @cwds && Time.now - @cwds_at < CWD_TTL

    @cwds_at = Time.now
    @cwds = {}
    pid = nil
    `lsof -d cwd -Fpn 2>/dev/null`.each_line do |line|
      case line[0]
      when "p" then pid = line[1..].to_i
      when "n" then @cwds[pid] = line[1..].chomp
      end
    end
    @cwds
  end

  # Activity Monitor's definitions: Used = App + Wired + Compressed.
  def memory
    stat = vm_stat
    page = stat[:page_size]
    total = sysctl("hw.memsize").to_i
    app = (sysctl("vm.page_pageable_internal_count").to_i - stat["Pages purgeable"]) * page
    wired = stat["Pages wired down"] * page
    compressed = stat["Pages occupied by compressor"] * page
    stored = stat["Pages stored in compressor"] * page
    swap = sysctl("vm.swapusage")
    now = Time.now

    Memory.new(
      total:, app:, wired:, compressed:,
      used: app + wired + compressed,
      compression_ratio: compressed.positive? ? stored.to_f / compressed : 0.0,
      cached: (stat["File-backed pages"] + stat["Pages purgeable"]) * page,
      free: stat["Pages free"] * page,
      swap_used: swap_bytes(swap, "used"),
      swap_total: swap_bytes(swap, "total"),
      pressure: 100 - sysctl("kern.memorystatus_level").to_i,
      swapouts_per_sec: rate(:swapouts, stat["Swapouts"] * page, now),
      compressions_per_sec: rate(:compressions, stat["Compressions"] * page, now)
    )
  end

  def vm_stat
    out = `vm_stat`
    counts = out.scan(/^"?([^:"]+)"?:\s+(\d+)\.?$/).to_h { |k, v| [k, v.to_i] }
    counts.default = 0
    counts[:page_size] = out[/page size of (\d+) bytes/, 1].to_i
    counts
  end

  def sysctl(name) = `sysctl -n #{name}`.strip

  def swap_bytes(text, field)
    value, unit = text.match(/#{field} = ([\d.]+)([KMG])/)&.captures
    return 0 unless value

    (value.to_f * { "K" => 1024, "M" => 1024**2, "G" => 1024**3 }.fetch(unit)).round
  end

  # Per-second change of a counter since the previous sample.
  def rate(name, value, now)
    @last ||= {}
    previous = @last[name]
    @last[name] = [value, now]
    return 0.0 unless previous

    elapsed = now - previous[1]
    elapsed.positive? ? (value - previous[0]) / elapsed : 0.0
  end
end
