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
