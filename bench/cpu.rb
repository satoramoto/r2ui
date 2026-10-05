# frozen_string_literal: true

# The CPU a terminal program uses while running in a pty of a given size: CPU time (user + system,
# from `ps -o time`) over a window after a warm-up, as a percentage of one core. This is how
# docs/performance.md measures a real consumer (agentmon) end to end.
#
#   ruby bench/cpu.rb [--cols 100] [--rows 50] [--warmup 5] [--seconds 20] -- COMMAND ARGS...
#
# The program's output is read and discarded. It is stopped (TERM, then KILL) on every exit path.

require "io/console"
require "optparse"
require "pty"

opts = { cols: 100, rows: 50, warmup: 5.0, seconds: 20.0, chdir: Dir.pwd }
OptionParser.new do |o|
  o.on("--cols N", Integer) { |v| opts[:cols] = v }
  o.on("--rows N", Integer) { |v| opts[:rows] = v }
  o.on("--warmup S", Float) { |v| opts[:warmup] = v }
  o.on("--seconds S", Float) { |v| opts[:seconds] = v }
  o.on("--chdir DIR") { |v| opts[:chdir] = v }
end.parse!(ARGV)
abort "usage: ruby bench/cpu.rb [options] -- COMMAND ARGS..." if ARGV.empty?

# CPU seconds used so far by `pid` and its descendants (bundle exec may leave a parent around).
def cpu_seconds(pid)
  table = `ps -A -o pid=,ppid=,time=`.lines.map(&:split)
  pids = [pid]
  loop do
    more = table.select { |_, ppid, _| pids.include?(ppid.to_i) }.map { |p, _, _| p.to_i } - pids
    break if more.empty?

    pids.concat(more)
  end
  table.select { |p, _, _| pids.include?(p.to_i) }.sum do |_, _, time|
    parts = time.split(":").map(&:to_f)
    parts.reverse.each_with_index.sum { |v, i| v * (60**i) }
  end
end

master, slave = PTY.open
slave.winsize = [opts[:rows], opts[:cols]]
env = { "COLUMNS" => opts[:cols].to_s, "LINES" => opts[:rows].to_s, "TERM" => ENV.fetch("TERM", "xterm-256color") }
pid = Process.spawn(env, *ARGV, in: slave, out: slave, err: slave, chdir: opts[:chdir], pgroup: true)
slave.close
reader = Thread.new do
  loop { master.readpartial(65_536) }
rescue IOError, Errno::EIO
  nil
end

begin
  sleep opts[:warmup]
  start = cpu_seconds(pid)
  sleep opts[:seconds]
  used = cpu_seconds(pid) - start
  puts format("%.1f%% CPU (%.2f s over %.0f s) %s", used * 100.0 / opts[:seconds], used, opts[:seconds], ARGV.join(" "))
ensure
  begin
    Process.kill("-TERM", pid)
    gone = 30.times.any? do
      Process.waitpid(pid, Process::WNOHANG) || (sleep(0.1) && false)
    end
    unless gone
      Process.kill("-KILL", pid)
      Process.waitpid(pid)
    end
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end
  master.close unless master.closed?
  reader.join(1)
end
