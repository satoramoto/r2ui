# frozen_string_literal: true

require "yaml"
require "tmpdir"
require "open3"
require "rbconfig"
require "etc"
require "fileutils"
require "set"
require_relative "pty_runner"

module Conformance
  ROOT = File.expand_path("../..", __dir__)
  DIR = File.join(ROOT, "conformance")
  CASES = File.join(DIR, "cases")
  GOLDEN = File.join(DIR, "golden")
  RATCHET = File.join(DIR, "ratchet")
  CONCESSIONS = File.join(DIR, "concessions")
  CHILD = File.join(DIR, "lib", "child.rb")

  DEFAULT_SIZE = "80x24"
  LEAK_EXIT = 97 # child.rb exits with this when a real bubbletea/lipgloss file loads under r2ui
  QUIET = Float(ENV.fetch("CONFORMANCE_QUIET", "0.3"))
  TIMEOUT = Float(ENV.fetch("CONFORMANCE_TIMEOUT", "15"))

  # Environment every case runs under, recording and checking alike: a true-colour xterm, UTF-8,
  # and nothing from bundler (recording must see the installed upstream gems).
  # CI is dropped because termenv (under lipgloss) treats any non-empty CI as "not a TTY" and
  # renders without colour; GitHub runners set CI=true, which made goldens machine-dependent.
  def self.child_env
    drop = ENV.keys.select { |k| k.start_with?("BUNDLE_", "BUNDLER_") } +
           %w[CI RUBYOPT RUBYLIB NO_COLOR CLICOLOR CLICOLOR_FORCE COLUMNS LINES TERM_PROGRAM TMUX STY]
    env = drop.to_h { |k| [k, nil] }
    env.merge(
      "TERM" => "xterm-256color",
      "COLORTERM" => "truecolor",
      "LANG" => "C.UTF-8",
      "LC_ALL" => "C.UTF-8",
      "RUNEWIDTH_EASTASIAN" => "0"
    )
  end

  # One case file: conformance/cases/<id>.rb. Optional YAML after `__END__` configures it; a
  # `steps:` list makes it a program case, otherwise it is a value case.
  class Case
    attr_reader :id, :path, :config

    def self.all
      Dir.glob(File.join(CASES, "**", "*.rb")).sort.map { |p| new(p) }
    end

    def initialize(path)
      @path = path
      @id = path.delete_prefix("#{CASES}/").delete_suffix(".rb")
      _code, yaml = File.read(path).split(/^__END__\r?\n/, 2)
      @config = yaml ? (YAML.safe_load(yaml) || {}) : {}
      raise ArgumentError, "#{@id}: __END__ section must be a YAML mapping" unless @config.is_a?(Hash)
    end

    def area = id.split("/").first
    def program? = config.key?("steps")
    def golden_path = File.join(GOLDEN, "#{id}.txt")

    def size = Conformance.parse_size(config.fetch("size", DEFAULT_SIZE), "#{id}: size")

    # Notes about the last run that don't belong in the golden (content scrolled off the top or
    # rows that overflowed the width before a snapshot). `record` prints them on stderr.
    def warnings = @warnings || []

    def golden
      File.exist?(golden_path) ? File.read(golden_path, encoding: "UTF-8") : nil
    end

    def header
      "# conformance golden for #{id}: recorded from the upstream gems by `bin/conformance record`. Never edit by hand.\n"
    end

    # Runs the case and returns [text, error]; text is the golden-format output (without header).
    # flavor :real loads the upstream gems, :r2ui loads them through r2ui/drop_in.
    def run(flavor)
      @flavor = flavor
      @warnings = []
      ruby = [RbConfig.ruby]
      ruby += ["-I", File.join(ROOT, "lib"), "-r", "r2ui/drop_in"] if flavor == :r2ui
      program? ? run_program(ruby) : run_value(ruby)
    rescue PtyRunner::Timeout, ArgumentError, KeyError => e
      [nil, e.message]
    end

    private

    def spawn_env(extra = {})
      Conformance.child_env.merge("CONFORMANCE_SIZE" => size.join("x"),
                                  "CONFORMANCE_FLAVOR" => @flavor.to_s).merge(extra)
    end

    def runner(ruby, env)
      cols, rows = size
      PtyRunner.new(cmd: ruby + [CHILD, path], env: env, cols: cols, rows: rows,
                    quiet: Float(config.fetch("quiet", QUIET)), timeout: TIMEOUT, chdir: ROOT)
    end

    # Value cases still run under a pty so the gems see a true-colour terminal; the result comes
    # back through a file, and the screen (errors, stray output) is only used for diagnostics.
    def run_value(ruby)
      Dir.mktmpdir("conformance") do |dir|
        out = File.join(dir, "out")
        screen = nil
        status = nil
        runner(ruby, spawn_env("CONFORMANCE_OUT" => out)).run do |r|
          status = r.wait_exit
          screen = r.snapshot_lines.reject(&:empty?).join("\n")
        end
        return [nil, "exit #{status}\n#{screen}"] unless status.zero? && File.exist?(out)

        [format_value(File.binread(out).force_encoding("UTF-8")), nil]
      end
    end

    def format_value(str)
      str.split("\n", -1).map(&:inspect).join("\n") << "\n"
    end

    def run_program(ruby)
      steps = config.fetch("steps")
      raise ArgumentError, "#{id}: steps must be a list" unless steps.is_a?(Array)

      out = +"size: #{size.join('x')}\n"
      runner(ruby, spawn_env).run do |r|
        r.wait_ready
        steps.each_with_index do |step, i|
          step = { "snapshot" => step } if step.is_a?(String)
          raise ArgumentError, "#{id}: step #{i + 1} must be a mapping" unless step.is_a?(Hash)

          unknown = step.keys - STEP_KEYS
          raise ArgumentError, "#{id}: step #{i + 1} has unknown keys #{unknown.join(', ')}" unless unknown.empty?
          if step.key?("snapshot") && step["snapshot"].to_s.empty?
            raise ArgumentError, "#{id}: step #{i + 1} has an empty snapshot name"
          end

          r.resize(*Conformance.parse_size(step["resize"], "#{id}: step #{i + 1} resize")) if step["resize"]
          r.send_keys(Array(step["keys"])) if step["keys"]
          r.send_input(step["input"].to_s) if step["input"]
          r.wait_for(step["wait_for"].to_s) if step["wait_for"]
          status = r.wait_exit if step["exit"]
          next unless step["snapshot"]

          note_overflow(step["snapshot"], *r.take_overflow)
          out << "== #{step['snapshot']}\n"
          out << "exit: #{status}\n" if step["exit"]
          out << r.snapshot(title: config["window_title"] == true)
        end
        if r.exited? && r.exit_status == LEAK_EXIT
          return [nil, "exit #{LEAK_EXIT}: a real upstream gem was loaded under r2ui\n#{r.snapshot_lines.reject(&:empty?).join("\n")}"]
        end
      end
      [out, nil]
    end

    def note_overflow(snapshot, scrolled, wrapped)
      if scrolled.positive?
        @warnings << "#{id}: before snapshot #{snapshot}, #{scrolled} non-blank row(s) scrolled off the top " \
                     "of the screen; the snapshot can't show them (use a taller size:)"
      end
      return unless wrapped.positive?

      @warnings << "#{id}: before snapshot #{snapshot}, a row overflowed the width and wrapped " \
                   "#{wrapped} time(s) (use a wider size: if that isn't the point of the case)"
    end
  end

  STEP_KEYS = %w[resize keys input wait_for exit snapshot].freeze

  # "COLSxROWS" -> [cols, rows]
  def self.parse_size(value, what)
    m = /\A(\d+)x(\d+)\z/.match(value.to_s)
    raise ArgumentError, "#{what} must look like 80x24, got #{value.inspect}" unless m && m[1].to_i.positive? && m[2].to_i.positive?

    [m[1].to_i, m[2].to_i]
  end

  # Runs cases in parallel (each is its own subprocess and pty), yielding results in id order.
  def self.run_all(cases, flavor, jobs:)
    queue = Queue.new
    cases.each_with_index { |c, i| queue << [c, i] }
    results = Array.new(cases.size)
    workers = Array.new([jobs, cases.size].min) do
      Thread.new do
        loop do
          c, i = queue.pop(true)
          results[i] = [c, *c.run(flavor)]
        rescue ThreadError
          break
        end
      end
    end
    workers.each(&:join)
    results
  end

  def self.diff(expected, actual)
    Dir.mktmpdir("conformance") do |dir|
      a = File.join(dir, "golden")
      b = File.join(dir, "r2ui")
      File.write(a, expected)
      File.write(b, actual)
      out, = Open3.capture2("diff", "-u", "--label", "golden (upstream gems)", "--label", "r2ui", a, b)
      out
    end
  end

  # conformance/ratchet/<area>.txt: one case id per line; `#` starts a comment.
  # Returns [[id, file], ...].
  def self.ratchet(dir = RATCHET)
    ledger(dir).map { |id, file, _| [id, file] }
  end

  # Adds ids to a ratchet file, each before the first listed id that sorts after it (so a sorted
  # list stays sorted). Comment and blank lines stay where they are. Returns the ids added.
  def self.add_to_ratchet(path, ids)
    lines = File.exist?(path) ? File.readlines(path, chomp: true) : []
    listed = lines.map { |l| l.split("#", 2).first.to_s.strip }
    added = (ids.uniq - listed).sort
    added.each do |id|
      at = listed.index { |l| !l.empty? && l > id } || lines.size
      lines.insert(at, id)
      listed.insert(at, id)
    end
    File.write(path, lines.map { |l| "#{l}\n" }.join) unless added.empty?
    added
  end

  # conformance/concessions/<area>.txt: `<id>  # reason`, one per line; the reason is required.
  # Returns [[id, file, reason], ...]; reason is nil when the line has none.
  def self.concessions(dir = CONCESSIONS) = ledger(dir)

  def self.ledger(dir)
    Dir.glob(File.join(dir, "*.txt")).sort.flat_map do |file|
      File.readlines(file, chomp: true).filter_map do |line|
        id, reason = line.split("#", 2).map(&:strip)
        next if id.nil? || id.empty?

        [id, File.basename(file), reason.nil? || reason.empty? ? nil : reason]
      end
    end
  end

  # Problems with the ratchet and concession lists themselves, as messages: an id with no case,
  # a concession without a reason, or an id both ratcheted and conceded.
  def self.ledger_problems(ratchet, concessions, case_ids)
    known = case_ids.to_set
    problems = ratchet.reject { |id, _| known.include?(id) }
                      .map { |id, file| "UNKNOWN #{id} (listed in conformance/ratchet/#{file}, no such case)" }
    concessions.each do |id, file, reason|
      problems << "UNKNOWN #{id} (listed in conformance/concessions/#{file}, no such case)" unless known.include?(id)
      problems << "NO REASON #{id} (conformance/concessions/#{file}: write `#{id}  # why r2ui differs`)" unless reason
    end
    (ratchet.map(&:first) & concessions.map(&:first)).each do |id|
      problems << "BOTH #{id} is in conformance/ratchet/ and conformance/concessions/; a case is one or the other"
    end
    problems
  end
end
