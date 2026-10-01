# frozen_string_literal: true

require "test_helper"
require "open3"
require_relative "../../conformance/lib/harness"

class HarnessTest < Minitest::Test
  BIN = File.expand_path("../../bin/conformance", __dir__)

  # termenv treats a non-empty CI as "not a TTY" and drops all colour, so CI must not reach cases.
  def test_child_env_unsets_ci
    env = Conformance.child_env
    assert env.key?("CI")
    assert_nil env["CI"]
  end

  def test_check_with_unmatched_filter_fails
    _out, status = Open3.capture2e(RbConfig.ruby, BIN, "check", "no/such/case/anywhere")
    refute status.success?
  end

  def test_stop_kills_the_whole_process_group
    grandchild = nil
    runner = Conformance::PtyRunner.new(cmd: ["sh", "-c", "sleep 60 & echo PID=$!; wait"], env: {},
                                        cols: 40, rows: 5, quiet: 0.1, timeout: 5)
    runner.run do |r|
      r.wait_for("PID=")
      grandchild = Integer(r.snapshot_lines.join[/PID=(\d+)/, 1])
    end
    sleep 0.1
    assert_raises(Errno::ESRCH) { Process.kill(0, grandchild) }
  end

  # A value case's own top-level `out` must not redirect where the harness writes the result.
  def test_value_case_locals_do_not_clobber_the_harness
    Dir.mktmpdir do |dir|
      kase = File.join(dir, "case.rb")
      decoy = File.join(dir, "decoy")
      File.write(kase, "out = #{decoy.inspect}\nresult = 1\ncase_path = nil\n'ok'\n")
      env = { "CONFORMANCE_SIZE" => "10x2", "CONFORMANCE_OUT" => File.join(dir, "out") }
      log, status = Open3.capture2e(env, RbConfig.ruby, Conformance::CHILD, kase)
      assert status.success?, log
      assert_equal "ok", File.read(File.join(dir, "out"))
      refute File.exist?(decoy)
    end
  end

  def program_case(dir, code, yaml)
    path = File.join(dir, "case.rb")
    File.write(path, "#{code}\n__END__\n#{yaml}")
    Conformance::Case.new(path)
  end

  def test_null_snapshot_name_is_an_error
    Dir.mktmpdir do |dir|
      c = program_case(dir, "puts 'hi'; sleep 5", "steps:\n  - snapshot:\n")
      text, error = c.run(:real)
      assert_nil text
      assert_match(/step 1 has an empty snapshot name/, error)
    end
  end

  def test_resize_step_resizes_the_pty_and_the_screen
    Dir.mktmpdir do |dir|
      code = 'require "io/console"; trap("WINCH") { puts "size=#{$stdout.winsize.reverse.join("x")}" }; ' \
             'puts "ready"; sleep 5'
      c = program_case(dir, code, "size: 30x6\nsteps:\n  - resize: 20x4\n    snapshot: small\n")
      text, error = c.run(:real)
      assert_nil error
      assert_includes text, "size=20x4"
      assert_equal 4, text[/== small\n.*\z/m].lines.count { |l| l.match?(/^\d\|/) }
    end
  end

  def test_window_title_is_in_snapshots_only_when_the_case_opts_in
    Dir.mktmpdir do |dir|
      code = 'print "\e]2;My title\a"; puts "x"; sleep 5'
      text, = program_case(dir, code, "size: 20x3\nsteps: [s]\n").run(:real)
      refute_includes text, "title:"
      text, = program_case(dir, code, "size: 20x3\nwindow_title: true\nsteps: [s]\n").run(:real)
      assert_includes text, "title: \"My title\"\n"
    end
  end

  def test_scrolling_and_wrapping_before_a_snapshot_are_warnings
    Dir.mktmpdir do |dir|
      c = program_case(dir, 'puts (1..5).map { |i| "line #{i}" }; puts "x" * 15; sleep 5',
                       "size: 10x3\nsteps: [s]\n")
      text, error = c.run(:real)
      assert_nil error
      refute_includes text, "scrolled"
      assert c.warnings.any? { |w| w.include?("scrolled off the top") }, c.warnings.inspect
      assert c.warnings.any? { |w| w.include?("overflowed the width") }, c.warnings.inspect
    end
  end

  def test_concessions_need_a_reason_a_case_and_no_ratchet_entry
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, "bubbletea.txt"), <<~TXT)
        # header comment
        bubbletea/a  # upstream drops all but the first key of a read
        bubbletea/b
        bubbletea/gone  # no such case
      TXT
      conceded = Conformance.concessions(dir)
      assert_equal ["bubbletea/a", "bubbletea.txt", "upstream drops all but the first key of a read"], conceded.first
      problems = Conformance.ledger_problems([["bubbletea/a", "bubbletea.txt"]], conceded,
                                             %w[bubbletea/a bubbletea/b])
      assert(problems.any? { |p| p.start_with?("UNKNOWN bubbletea/gone") })
      assert(problems.any? { |p| p.start_with?("NO REASON bubbletea/b") })
      assert(problems.any? { |p| p.start_with?("BOTH bubbletea/a") })
      assert_equal 3, problems.size
    end
  end

  def test_child_fails_when_real_gem_is_loaded_under_r2ui
    Dir.mktmpdir do |dir|
      fake = File.join(dir, "gems", "lipgloss-9.9.9", "lib")
      FileUtils.mkdir_p(fake)
      File.write(File.join(fake, "fake_lipgloss.rb"), "")
      kase = File.join(dir, "case.rb")
      File.write(kase, "require #{File.join(fake, 'fake_lipgloss').inspect}\n'ok'\n")
      env = { "CONFORMANCE_SIZE" => "10x2", "CONFORMANCE_FLAVOR" => "r2ui",
              "CONFORMANCE_OUT" => File.join(dir, "out") }
      _out, status = Open3.capture2e(env, RbConfig.ruby, Conformance::CHILD, kase)
      assert_equal Conformance::LEAK_EXIT, status.exitstatus
      refute File.exist?(File.join(dir, "out"))
    end
  end
end
