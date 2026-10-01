# frozen_string_literal: true

require "pty"
require "io/console"
require_relative "vt"

module Conformance
  # Spawns a command under a pty of a fixed size, plays scripted input, and snapshots the screen
  # (decoded by Conformance::VT) at named steps. The VT answers terminal queries (cursor
  # position, background colour, ...) the way a real terminal would, so programs that ask don't
  # stall waiting for a reply.
  class PtyRunner
    class Timeout < StandardError; end

    KEYS = {
      "up" => "\e[A", "down" => "\e[B", "right" => "\e[C", "left" => "\e[D",
      "home" => "\e[H", "end" => "\e[F", "pgup" => "\e[5~", "pgdown" => "\e[6~",
      "insert" => "\e[2~", "delete" => "\e[3~",
      "enter" => "\r", "tab" => "\t", "shift+tab" => "\e[Z", "esc" => "\e",
      "backspace" => "\x7f", "space" => " ",
      **("a".."z").to_h { |c| ["ctrl+#{c}", (c.ord - 96).chr] }
    }.freeze

    POLL = 0.005

    attr_reader :vt, :exit_status

    # quiet: seconds without output that count as "idle".
    # timeout: seconds any single wait may take before the case errors.
    def initialize(cmd:, env:, cols:, rows:, quiet:, timeout:, chdir: Dir.pwd)
      @cmd = cmd
      @env = env
      @quiet = quiet
      @timeout = timeout
      @chdir = chdir
      @vt = VT.new(cols: cols, rows: rows)
      @lock = Mutex.new
      @last_output = nil
      @bytes = 0
      @exit_status = nil
    end

    # Runs the block with the program started; always kills it and closes the pty afterwards.
    def run
      # Both IOs are the pty master: one opened for reading, one for writing.
      @master, @input, @pid = PTY.spawn(@env, *@cmd, chdir: @chdir)
      @input.sync = true
      @write_lock = Mutex.new
      @started = now
      @reader = Thread.new { read_loop }
      yield self
    ensure
      stop
    end

    def self.key_bytes(name)
      KEYS.fetch(name.to_s) { name.to_s }
    end

    # Waits until the program has written something and then gone quiet (or exited).
    def wait_ready
      wait_until("first output") { @bytes.positive? || exited? }
      wait_quiet
    end

    def send_keys(names)
      names.each do |name|
        write(self.class.key_bytes(name))
        wait_quiet
      end
    end

    def send_input(bytes)
      write(bytes)
      wait_quiet
    end

    def wait_for(text)
      wait_until("screen to contain #{text.inspect}") { snapshot_lines.any? { |l| l.include?(text) } }
      wait_quiet
    end

    # Waits for the program to exit and its last output to arrive.
    def wait_exit
      wait_until("program to exit") { exited? }
      @reader.join(@timeout)
      @exit_status
    end

    # Resizes the pty (the kernel sends the program SIGWINCH) and the decoded screen, then waits
    # for idle.
    def resize(cols, rows)
      @lock.synchronize { @vt.resize(cols, rows) }
      @master.winsize = [rows, cols]
      @mark = now
      wait_quiet
    end

    def snapshot(title: false)
      @lock.synchronize { @vt.snapshot(title: title) }
    end

    # Returns [rows scrolled off the top, characters wrapped past the width] since the last call.
    def take_overflow
      @lock.synchronize do
        counts = [@vt.scrolled_off, @vt.wrapped]
        @vt.scrolled_off = @vt.wrapped = 0
        counts
      end
    end

    def snapshot_lines
      @lock.synchronize { @vt.lines }
    end

    def exited?
      return true if @exit_status

      pid, status = Process.waitpid2(@pid, Process::WNOHANG)
      @exit_status = status.exitstatus || -(status.termsig || 0) if pid
      !@exit_status.nil?
    rescue Errno::ECHILD
      @exit_status ||= -1
      true
    end

    private

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    def write(bytes)
      @write_lock.synchronize { @input.write(bytes) }
      @mark = now
    rescue Errno::EIO, Errno::EPIPE # the program already exited
      @mark = now
    end

    def read_loop
      loop do
        chunk = @master.readpartial(65_536)
        reply = @lock.synchronize do
          @bytes += chunk.bytesize
          @last_output = now
          @vt.feed(chunk)
        end
        @write_lock.synchronize { @input.write(reply) } unless reply.nil? || reply.empty?
      end
    rescue EOFError, Errno::EIO, IOError
      nil
    end

    # Idle means: no output for @quiet seconds, measured from the later of the last output and the
    # last input we sent (so a key that changes nothing still waits one quiet window).
    def wait_quiet
      wait_until("output to go quiet") do
        next true if exited? && !@reader.alive?

        since = [@last_output, @mark, @started].compact.max
        now - since >= @quiet
      end
    end

    def wait_until(what)
      deadline = now + @timeout
      until yield
        raise Timeout, "timed out after #{@timeout}s waiting for #{what}" if now > deadline

        sleep POLL
      end
    end

    def stop
      return unless @pid

      # PTY.spawn makes the child a session (and process group) leader, so -pid signals the
      # whole group: anything the case forked dies with it, even after the leader has exited.
      %w[TERM KILL].each do |sig|
        begin
          Process.kill(sig, -@pid)
        rescue Errno::ESRCH, Errno::EPERM
          break
        end
        20.times { break if exited?; sleep 0.02 }
      end
      exited?
      @reader&.join(1)
      @reader&.kill
      [@input, @master].each { |io| io.close unless io.nil? || io.closed? }
    end
  end
end
