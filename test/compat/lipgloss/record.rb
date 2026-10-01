# frozen_string_literal: true

# Records lipgloss conformance goldens from the REAL lipgloss gem (0.2.2, Go lipgloss v1.1.0).
#
# Re-record (from the repo root, with plain ruby, never `bundle exec`; the real gem must be installed
# with `gem install lipgloss -v 0.2.2`):
#
#   ruby test/compat/lipgloss/record.rb              # every area
#   ruby test/compat/lipgloss/record.rb style table  # some areas
#
# Goldens (test/compat/lipgloss/goldens/<area>.json) are written only by this script and are never
# edited by hand: change or add a case in cases/<area>.rb and re-record.
#
# How it works: for each color profile the parent spawns one child under a pty (PTY.spawn), with a
# terminal environment that makes Go's termenv pick that profile. The child loads the real gem and the
# cases, evaluates each case and appends `[id, result]` JSON lines to a temp file (never the pty). The
# parent answers the terminal queries Go writes to the pty (OSC 11 background color, then cursor
# position report) with a dark or light background, so recording never waits on termenv's 5s timeout.
# If a case crashes the child (a Go panic kills the process), the parent records the crash and restarts
# the child after that case; crashing cases abort the run, since they can't be compared.

require "json"
require "rbconfig"

HERE = __dir__
SELF = File.expand_path(__FILE__)
GEM_VERSION = "0.2.2"

if defined?(Bundler)
  # Under bundler the real gem is hidden (and r2ui may be on the load path): re-run outside it.
  Bundler.with_unbundled_env { exec(RbConfig.ruby, SELF, *ARGV) }
end

require_relative "cases"

# ---------------------------------------------------------------------------------------------------
# Child: runs inside the pty with the real gem loaded.
# ---------------------------------------------------------------------------------------------------
if ARGV[0] == "--child"
  ids_path, out_path = ARGV[1], ARGV[2]
  areas, ids = JSON.parse(File.read(ids_path)).values_at("areas", "ids")

  begin
    gem "lipgloss", GEM_VERSION
    require "lipgloss"
  rescue LoadError, Gem::LoadError => e
    warn "record.rb: the real lipgloss gem #{GEM_VERSION} is not loadable: #{e.message}"
    exit 3
  end
  gem_dir = Gem.loaded_specs.fetch("lipgloss").gem_dir
  entry = $LOADED_FEATURES.find { |f| f.end_with?("/lipgloss.rb") }
  if entry.nil? || !entry.start_with?(gem_dir) || $LOADED_FEATURES.any? { |f| f.include?("r2ui/compat") }
    warn "record.rb: loaded a lipgloss that is not the real gem"
    exit 3
  end

  LipglossCases.load_areas(areas)
  File.open(out_path, "a") do |out|
    out.sync = true
    probe = {
      "dark" => Lipgloss.has_dark_background?,
      "fg" => Lipgloss::Style.new.foreground("#ff0000").render("x"),
      "upstream" => Lipgloss.upstream_version
    }
    out.puts(JSON.generate(["__probe__", probe]))
    ids.each do |id|
      out.puts(JSON.generate([id, LipglossCases.capture(LipglossCases[id].code, "case:#{id}")]))
    end
  end
  exit 0
end

# ---------------------------------------------------------------------------------------------------
# Parent
# ---------------------------------------------------------------------------------------------------
require "pty"
require "tmpdir"

begin
  Gem::Specification.find_by_name("lipgloss", GEM_VERSION)
rescue Gem::MissingSpecError
  abort "record.rb: the real lipgloss gem #{GEM_VERSION} is not installed (gem install lipgloss -v #{GEM_VERSION})"
end

UNSET = %w[
  NO_COLOR CLICOLOR CLICOLOR_FORCE COLORTERM TERM TERM_PROGRAM TERM_PROGRAM_VERSION COLORFGBG TMUX STY
  GOOGLE_CLOUD_SHELL LC_TERMINAL LC_TERMINAL_VERSION ITERM_SESSION_ID ITERM_PROFILE KITTY_WINDOW_ID
  WT_SESSION VTE_VERSION WEZTERM_PANE ALACRITTY_LOG ALACRITTY_SOCKET ALACRITTY_WINDOW_ID
  RUBYOPT RUBYLIB BUNDLE_GEMFILE BUNDLE_BIN_PATH BUNDLER_SETUP
].freeze

PROFILE_ENV = {
  "true_color" => { "TERM" => "xterm-256color", "COLORTERM" => "truecolor" },
  "ansi256" => { "TERM" => "xterm-256color" },
  "ansi" => { "TERM" => "xterm" },
  "ascii" => { "TERM" => "dumb" },
  "true_color_light" => { "TERM" => "xterm-256color", "COLORTERM" => "truecolor" }
}.freeze

LIGHT = %w[true_color_light].freeze
QUERY = /\e\]11;\?(?:\e\\|\a)|\e\[6n/
CHILD_TIMEOUT = 600

# Terminal answers for the queries termenv writes: background color, then cursor position.
def answer(query, light)
  if query.start_with?("\e]11")
    light ? "\e]11;rgb:ffff/ffff/ffff\a" : "\e]11;rgb:0000/0000/0000\a"
  else
    "\e[1;1R"
  end
end

$children = []
at_exit do
  $children.each do |pid|
    Process.kill("KILL", pid)
    Process.wait(pid)
  rescue StandardError
    nil
  end
end
%w[INT TERM HUP].each { |sig| trap(sig) { exit 130 } }

# Runs one child for `ids` under `profile`; returns [results hash (incl. "__probe__"), exit status, pty text].
def run_child(profile, areas, ids, dir)
  ids_path = File.join(dir, "ids-#{profile}.json")
  out_path = File.join(dir, "out-#{profile}.jsonl")
  File.write(ids_path, JSON.generate("areas" => areas, "ids" => ids))
  File.write(out_path, "")

  env = UNSET.to_h { |k| [k, nil] }.merge(PROFILE_ENV.fetch(profile))
  light = LIGHT.include?(profile)
  text = +""
  status = nil
  reader, writer, pid = PTY.spawn(env, RbConfig.ruby, SELF, "--child", ids_path, out_path)
  $children << pid
  begin
    buffer = +""
    deadline = Time.now + CHILD_TIMEOUT
    loop do
      raise "child for #{profile} timed out" if Time.now > deadline
      next unless reader.wait_readable(1)

      chunk = begin
        reader.readpartial(65_536)
      rescue EOFError, Errno::EIO
        break
      end
      buffer << chunk.b
      while (match = QUERY.match(buffer))
        writer.write(answer(match[0], light))
        writer.flush
        text << match.pre_match
        buffer = match.post_match
      end
      # Keep a possible partial query at the end of the buffer for the next chunk.
      if (cut = buffer.rindex("\e"))
        text << buffer[0...cut]
        buffer = buffer[cut..]
      else
        text << buffer
        buffer = +""
      end
    end
    text << buffer
  ensure
    begin
      Process.kill("KILL", pid) unless Process.waitpid(pid, Process::WNOHANG)
      _, status = Process.waitpid2(pid)
    rescue Errno::ECHILD
      status ||= $?
    end
    $children.delete(pid)
    reader.close unless reader.closed?
    writer.close unless writer.closed?
  end

  results = {}
  File.foreach(out_path) do |line|
    id, value = JSON.parse(line)
    results[id] = value
  rescue JSON::ParserError
    break # a partial last line from a crash
  end
  [results, status, text]
end

areas = ARGV.empty? ? LipglossCases.areas : ARGV
unknown = areas - LipglossCases.areas
abort "record.rb: unknown area(s): #{unknown.join(", ")} (known: #{LipglossCases.areas.join(", ")})" unless unknown.empty?

LipglossCases.load_areas(areas)
all_ids = areas.flat_map { |a| LipglossCases.cases(a).map(&:id) }
started = Time.now

recorded = Hash.new { |h, k| h[k] = {} } # id => {profile => value}
crashes = Hash.new { |h, k| h[k] = [] }  # id => [profile]
probes = {}

Dir.mktmpdir("lipgloss-record") do |dir|
  LipglossCases::PROFILES.each_key do |profile|
    pending = all_ids
    until pending.empty?
      results, status, text = run_child(profile, areas, pending, dir)
      if status.nil? || status.exitstatus == 3 || !results.key?("__probe__")
        abort "record.rb: child failed to start for #{profile} (#{status.inspect}):\n#{text}"
      end
      probes[profile] ||= results.delete("__probe__")
      results.delete("__probe__")
      done = pending.take_while { |id| results.key?(id) }
      done.each { |id| recorded[id][profile] = results[id] }
      if done.size == pending.size
        pending = []
      else
        crasher = pending[done.size]
        crashes[crasher] << profile
        warn "record.rb: #{crasher} crashed the child (#{profile}, #{status.inspect}):\n#{text.lines.last(8).join}"
        pending = pending[(done.size + 1)..]
      end
    end
  end
end

# Poka-yoke: the pty must have produced each profile, and adaptive colors must flip with the background.
expected_fg = {
  "true_color" => "\e[38;2;255;0;0m", "true_color_light" => "\e[38;2;255;0;0m",
  "ansi256" => "\e[38;5;196m", "ansi" => "\e[91m", "ascii" => nil
}
problems = []
LipglossCases::PROFILES.each do |profile, spec|
  probe = probes[profile] or (problems << "#{profile}: no probe result" and next)
  problems << "#{profile}: has_dark_background? = #{probe["dark"]}, want #{spec[:dark]}" if probe["dark"] != spec[:dark]
  want = expected_fg.fetch(profile)
  got = probe["fg"]
  ok = want ? got.start_with?(want) : !got.include?("\e")
  problems << "#{profile}: foreground #ff0000 rendered #{got.inspect}" unless ok
end
abort "record.rb: terminal profiles not as expected:\n  #{problems.join("\n  ")}" unless problems.empty?

unless crashes.empty?
  abort "record.rb: these cases crash the real gem's process (remove them; nothing was written):\n" +
        crashes.map { |id, profiles| "  #{id} (#{profiles.join(", ")})" }.join("\n")
end

Dir.mkdir(LipglossCases::GOLDENS) unless Dir.exist?(LipglossCases::GOLDENS)
areas.each do |area|
  golden = {}
  LipglossCases.cases(area).each do |c|
    per = LipglossCases::PROFILES.keys.to_h { |p| [p, recorded[c.id].fetch(p)] }
    results = per.values.uniq.size == 1 ? { "*" => per.values.first } : per
    golden[c.id] = { "code" => c.code, "results" => results }
  end
  File.write(File.join(LipglossCases::GOLDENS, "#{area}.json"), JSON.pretty_generate(golden) + "\n")
  puts format("%-8s %4d cases", area, golden.size)
end
puts format("recorded %d cases x %d profiles in %.1fs (upstream %s)",
            all_ids.size, LipglossCases::PROFILES.size, Time.now - started, probes.values.first["upstream"])
