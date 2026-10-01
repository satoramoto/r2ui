# frozen_string_literal: true

require "test_helper"
require "pty"
require "io/console"
require "rbconfig"

# s10-suspend: ctrl+z suspends (Bubbletea's SuspendCommand), on_resume runs on ResumeMessage.
class SuspendTest < Minitest::Test
  def setup = R2UI.reset!

  def commands(command)
    case command
    when nil then []
    when Bubbletea::BatchCommand then command.commands.flat_map { |c| commands(c) }
    else [command]
    end
  end

  def app_with(&definition)
    R2UI.dashboard do
      instance_exec(&definition)
      row { panel(:main, resource: nil) { view { "resumed #{state[:resumed].to_i}" } } }
    end
    R2UI::App.new(R2UI.registry)
  end

  def test_suspendable_binds_ctrl_z_to_suspend
    app = app_with { suspendable }
    app.init

    out = app.press("ctrl+z").flat_map { |c| commands(c) }

    assert_equal [Bubbletea::SuspendCommand], out.map(&:class)
  ensure
    app&.stop
  end

  def test_ctrl_z_does_nothing_unless_suspendable
    app = app_with { nil }
    app.init

    out = app.press("ctrl+z").flat_map { |c| commands(c) }

    refute(out.any? { |c| c.is_a?(Bubbletea::SuspendCommand) })
  ensure
    app&.stop
  end

  def test_suspend_helper_returns_the_suspend_command
    app = app_with { every(1) { suspend } }
    _, command = app.init

    _, out = app.update(commands(command).first.callback.call)

    assert(commands(out).any? { |c| c.is_a?(Bubbletea::SuspendCommand) }, out.inspect)
  ensure
    app&.stop
  end

  def test_on_resume_runs_on_resume_message
    app = app_with do
      suspendable
      on_resume { state[:resumed] = state[:resumed].to_i + 1 }
      on_resume do
        flash "back"
        Bubbletea.set_window_title("back")
      end
    end
    app.init

    _, out = app.update(Bubbletea::ResumeMessage.new)

    assert_equal 1, app.state[:resumed]
    assert_match(/resumed 1/, app.view)
    assert_match(/back/, app.frame(40, 5).plain_lines.join("\n"))
    assert(commands(out).any? { |c| c.is_a?(Bubbletea::SetWindowTitleCommand) }, out.inspect)
  ensure
    app&.stop
  end

  def test_on_resume_needs_a_block
    assert_raises(ArgumentError) { R2UI.dashboard(:bad) { on_resume } }
  end

  APP = <<~RUBY
    require "r2ui"

    R2UI.dashboard do
      suspendable
      on_resume { state[:resumed] = state[:resumed].to_i + 1 }
      row { panel(:main, resource: nil) { view { "resumed:\#{state[:resumed].to_i}" } } }
    end

    R2UI.run
  RUBY

  LIB = File.expand_path("../../lib", __dir__)

  # The terminal is given back while stopped and taken again after SIGCONT.
  def test_ctrl_z_stops_the_process_with_the_terminal_restored_and_resumes
    master, slave = PTY.open
    slave.winsize = [12, 50]
    output = +"".b
    reader = Thread.new do
      loop { output << master.readpartial(4096) }
    rescue EOFError, Errno::EIO, IOError
      nil
    end
    # Its own process group, so the stop signal isn't discarded as for an orphaned group (CI).
    pid = Bundler.with_unbundled_env do
      Process.spawn(RbConfig.ruby, "-I", LIB, "-e", APP, in: slave, out: slave, err: slave, pgroup: true)
    end

    wait_until("first frame") { output.include?("resumed:0") }
    refute slave.echo?, "raw mode while running"

    master.write("\x1a") # ctrl+z
    wait_until("process stopped") { stopped?(pid) }
    assert slave.echo?, "terminal restored while stopped"
    assert output.end_with?("\e[?25h"), output[-40..].inspect

    Process.kill("CONT", pid)
    wait_until("resumed frame") { output.include?("resumed:1") }
    refute slave.echo?, "raw mode again after resume"

    master.write("q")
    status = wait_for_exit(pid)
    sleep 0.05
    pid = nil

    assert status.success?, output.inspect
    assert slave.echo?, "terminal restored at exit"
    assert output.end_with?("\e[?1049l\e[?25h"), output[-40..].inspect
  ensure
    if pid
      Process.kill("KILL", pid) rescue nil # rubocop:disable Style/RescueModifier
      Process.wait(pid) rescue nil # rubocop:disable Style/RescueModifier
    end
    slave&.close
    master&.close
    reader&.join(1)
    reader&.kill
  end

  private

  def stopped?(pid) = `ps -o stat= -p #{pid}`.strip.start_with?("T")

  def wait_until(what, timeout: 10)
    deadline = Time.now + timeout
    sleep 0.01 until yield || Time.now > deadline
    assert yield, "timed out waiting for #{what}"
  end

  def wait_for_exit(pid, timeout: 10)
    deadline = Time.now + timeout
    loop do
      _, status = Process.wait2(pid, Process::WNOHANG)
      return status if status
      raise "program did not exit within #{timeout}s" if Time.now > deadline

      sleep 0.01
    end
  end
end
