# frozen_string_literal: true

require_relative "helper"
require "pty"
require "open3"
require "rbconfig"
require "tmpdir"

# Bubbletea::Program against a real pty: the bytes upstream's Go side writes (x/ansi v0.8.0), raw mode,
# size, the input reader, and the exit-time restore. Where the real gem is installed, the same calls
# are also run through it in a subprocess and compared.
class BubbleteaProgramTest < Minitest::Test
  LIB = File.expand_path("../../../lib", __dir__)

  def setup
    @master, @slave = PTY.open
    @programs = []
  end

  def teardown
    @programs.each do |program|
      program.stop_input_reader
      program.exit_raw_mode
    end
    @master.close unless @master.closed?
    @slave.close unless @slave.closed?
  end

  def program(input: @slave, output: @slave)
    Bubbletea::Program.new(input: input, output: output).tap { |p| @programs << p }
  end

  # Everything written to the pty so far.
  def drain(io = @master, quiet: 0.05)
    out = +"".b
    while IO.select([io], nil, nil, quiet)
      chunk = io.read_nonblock(4096, exception: false)
      break if chunk.nil? || chunk == :wait_readable

      out << chunk
    end
    out
  rescue Errno::EIO
    out
  end

  def stty(*args) = IO.popen(["stty", *args], in: @slave, err: File::NULL, &:read).strip

  PENDIN = 0x20000000

  # The pty's saved mode (stty -g), minus PENDIN: the kernel sets that flag itself when canonical
  # mode comes back (the real gem's restore shows it too).
  def saved_mode
    stty("-g").sub(/lflag=(\h+)/) { "lflag=#{(Regexp.last_match(1).hex & ~PENDIN).to_s(16)}" }
  end

  def test_mode_toggles_write_upstream_bytes_and_are_idempotent
    p = program
    expected = {
      enter_alt_screen: "\e[?1049h\e[2J\e[H", exit_alt_screen: "\e[?1049l",
      hide_cursor: "\e[?25l", show_cursor: "\e[?25h",
      enable_mouse_cell_motion: "\e[?1002h\e[?1006h", enable_mouse_all_motion: "\e[?1003h\e[?1006h",
      disable_mouse: "\e[?1002l\e[?1003l\e[?1006l",
      enable_bracketed_paste: "\e[?2004h", disable_bracketed_paste: "\e[?2004l",
      enable_report_focus: "\e[?1004h", disable_report_focus: "\e[?1004l"
    }
    # Go guards alt screen, cursor and mouse-off with flags; mouse-on, paste and focus always write.
    calls = [
      [:exit_alt_screen, ""], [:enter_alt_screen, expected[:enter_alt_screen]], [:enter_alt_screen, ""],
      [:exit_alt_screen, expected[:exit_alt_screen]], [:exit_alt_screen, ""],
      [:show_cursor, ""], [:hide_cursor, expected[:hide_cursor]], [:hide_cursor, ""],
      [:show_cursor, expected[:show_cursor]], [:show_cursor, ""],
      [:disable_mouse, ""], [:enable_mouse_cell_motion, expected[:enable_mouse_cell_motion]],
      [:enable_mouse_all_motion, expected[:enable_mouse_all_motion]],
      [:disable_mouse, expected[:disable_mouse]], [:disable_mouse, ""],
      [:enable_bracketed_paste, expected[:enable_bracketed_paste]],
      [:enable_bracketed_paste, expected[:enable_bracketed_paste]],
      [:disable_bracketed_paste, expected[:disable_bracketed_paste]],
      [:disable_bracketed_paste, expected[:disable_bracketed_paste]],
      [:enable_report_focus, expected[:enable_report_focus]],
      [:disable_report_focus, expected[:disable_report_focus]],
      [:disable_report_focus, expected[:disable_report_focus]]
    ]
    calls.each do |method, bytes|
      assert_nil p.public_send(method), method
      assert_equal bytes.b, drain, method
    end
  end

  def test_raw_mode_and_exact_restore
    @slave.echo = false # a non-default prior mode, which must come back exactly
    before = saved_mode
    p = program

    assert_equal true, p.enter_raw_mode
    during = stty("-a")
    assert_match(/-icanon/, during)
    assert_match(/-isig/, during)
    assert_match(/-opost/, during)
    assert_equal true, p.enter_raw_mode
    assert_equal true, p.exit_raw_mode
    assert_equal before, saved_mode
    assert_equal true, p.exit_raw_mode
    assert_equal before, saved_mode
  end

  def test_raw_mode_fails_on_a_non_terminal
    reader, writer = IO.pipe
    p = program(input: reader, output: writer)
    assert_equal false, p.enter_raw_mode
    assert_equal true, p.exit_raw_mode
  ensure
    reader&.close
    writer&.close
  end

  def test_terminal_size_comes_from_the_output
    @slave.winsize = [30, 100]
    reader, writer = IO.pipe
    assert_equal [100, 30], program(input: reader, output: @slave).terminal_size
    assert_nil program(input: @slave, output: writer).terminal_size
  ensure
    reader&.close
    writer&.close
  end

  def test_reader_delivers_raw_chunks
    p = program
    p.enter_raw_mode
    assert_nil p.read_raw_input(10), "no reader yet"
    assert_equal true, p.start_input_reader
    assert_equal true, p.start_input_reader
    @master.write("abc")
    chunk = p.read_raw_input(1000)
    assert_equal "abc".b, chunk
    assert_equal Encoding::BINARY, chunk.encoding
    assert_nil p.read_raw_input(20)
  end

  def test_reader_chunks_are_at_most_256_bytes
    p = program
    p.enter_raw_mode
    p.start_input_reader
    @master.write("x" * 600)
    received = +"".b
    while (chunk = p.read_raw_input(500))
      assert_operator chunk.bytesize, :<=, 256
      received << chunk
      break if received.bytesize >= 600
    end
    assert_equal "x" * 600, received
  end

  def test_poll_event_decodes_and_queues_every_event_of_a_chunk
    p = program
    p.enter_raw_mode
    assert_nil p.poll_event(10), "no reader yet"
    p.start_input_reader
    events = R2UI::Compat::Tea::Input.parse_all("ab\e[A".b)
    assert_operator events.size, :>=, 3
    @master.write("ab\e[A")
    events.each { |event| assert_equal event, p.poll_event(1000) }
    assert_nil p.poll_event(20)
  end

  def test_stop_input_reader_stops_consuming_input
    p = program
    p.enter_raw_mode
    p.start_input_reader
    assert_nil p.stop_input_reader
    assert_nil p.stop_input_reader
    refute(Thread.list.any? { |t| t.name == "bubbletea input reader" && t.alive? })

    @master.write("xyz")
    assert IO.select([@slave], nil, nil, 1), "input left for the next reader"
    assert_equal "xyz", @slave.read_nonblock(16)
    assert_nil p.read_raw_input(10)
    assert_nil p.poll_event(10)

    assert_equal true, p.start_input_reader
    @master.write("q")
    assert_equal "q", p.read_raw_input(1000)
  end

  def test_reader_ends_at_eof
    reader, writer = IO.pipe
    p = program(input: reader, output: writer)
    p.start_input_reader
    writer.write("hi")
    assert_equal "hi", p.read_raw_input(1000)
    writer.close
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    while Thread.list.any? { |t| t.name == "bubbletea input reader" && t.alive? }
      flunk "reader still running after EOF" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      Thread.pass
    end
    assert_nil p.read_raw_input(10)
  ensure
    p&.stop_input_reader
    reader&.close
    writer.close unless writer.nil? || writer.closed?
  end

  def test_renderer_ids_share_the_program_counter
    p = program
    first = p.create_renderer
    assert_kind_of Integer, first
    assert_operator first, :>, 0
    program
    assert_equal first + 2, p.create_renderer
  end

  def test_argument_errors_match_the_c_extension
    p = program
    assert_raises_message(TypeError, "wrong argument type Integer (expected String)") { p.string_width(1) }
    assert_raises_message(ArgumentError, "string contains null byte") { p.string_width("a\0") }
    assert_raises_message(TypeError, "no implicit conversion from nil to integer") { p.read_raw_input(nil) }
    assert_raises_message(TypeError, "no implicit conversion of String into Integer") { p.poll_event("1") }
    assert_raises_message(RangeError, "integer 1099511627776 too big to convert to 'int'") { p.poll_event(2**40) }
    assert_raises_message(TypeError, "wrong argument type Integer (expected String)") { p.render(1, 2) }
    assert_raises_message(TypeError, "no implicit conversion of String into Integer") { p.render("x", "y") }
    assert_raises_message(TypeError, "no implicit conversion from nil to integer") { p.renderer_set_size(999, nil, 1) }
    assert_raises_message(TypeError, "no implicit conversion of nil into Integer") { p.renderer_clear(nil) }
    assert_nil p.renderer_set_alt_screen(-1, true)
    assert_nil p.render(999_999, "unknown ids are ignored")
    assert_raises_message(TypeError, "wrong argument type String (expected Integer)") { Bubbletea.get_key_name("x") }
    assert_raises_message(TypeError, "wrong argument type Integer (expected Integer)") { Bubbletea.get_key_name(2**70) }
    assert_raises_message(TypeError, "wrong argument type Float (expected Integer)") { Bubbletea.get_key_name(1.0) }
    assert_raises_message(TypeError, "wrong argument type nil (expected String)") { Bubbletea._set_window_title(nil) }
  end

  def test_module_functions
    assert_equal "v0.8.0", Bubbletea.upstream_version
    assert_equal "bubbletea v0.1.4 (upstream charmbracelet/x/ansi v0.8.0) [r2ui pure Ruby]", Bubbletea.version
    assert_equal $stdin.tty?, Bubbletea.tty?
  end

  def test_window_title_and_clear_screen_bytes
    original = $stdout
    $stdout = @slave
    Bubbletea._set_window_title("héllo")
    Bubbletea.clear_screen
    $stdout = original
    assert_equal "\e]2;héllo\a\e[2J\e[H".b, drain
  ensure
    $stdout = original
  end

  DIRTY = <<~RUBY
    p = Bubbletea::Program.new
    p.enter_raw_mode
    p.hide_cursor
    p.enter_alt_screen
    p.enable_mouse_cell_motion
    p.enable_bracketed_paste
    p.enable_report_focus
    $stdout.write("|exit|"); $stdout.flush
  RUBY

  def test_at_exit_restores_a_dirty_terminal
    before = saved_mode
    out = run_child("#{DIRTY}raise 'boom'")
    assert_equal "\e[?1002l\e[?1003l\e[?1006l\e[?2004l\e[?1004l\e[?1049l\e[?25h".b, out.split("|exit|".b, 2).last
    assert_equal before, saved_mode
  end

  def test_at_exit_writes_nothing_after_cleanup
    before = saved_mode
    cleanup = %w[disable_mouse disable_bracketed_paste disable_report_focus exit_alt_screen show_cursor exit_raw_mode]
    out = run_child("#{DIRTY}#{cleanup.map { |m| "p.#{m}" }.join("; ")}; $stdout.write('|done|'); $stdout.flush")
    assert out.end_with?("|done|".b), out.inspect
    assert_equal before, saved_mode
  end

  # The same calls through the real gem (when installed) and through ours, both in subprocesses
  # with stdout on a pipe and stdin on /dev/null.
  CONFORMANCE = <<~'RUBY'
    def mark(label) = ($stdout.write("|#{label}:"); $stdout.flush)
    def show(value) = ($stdout.write(value.inspect); $stdout.flush)
    a = Bubbletea::Program.new
    %i[enter_raw_mode exit_raw_mode terminal_size enter_alt_screen enter_alt_screen exit_alt_screen hide_cursor
       hide_cursor show_cursor show_cursor enable_mouse_cell_motion enable_mouse_all_motion disable_mouse disable_mouse
       enable_bracketed_paste disable_bracketed_paste enable_report_focus disable_report_focus stop_input_reader
       exit_alt_screen].each { |m| mark(m); show(a.public_send(m)) }
    [[:read_raw_input, 0], [:poll_event, 0], [:read_raw_input, nil], [:poll_event, "1"], [:poll_event, 2**40],
     [:string_width, 1], [:string_width, "a\0"], [:render, 1, 2], [:render, "x", "y"],
     [:renderer_set_size, 999, nil, 1], [:renderer_clear, nil], [:renderer_set_alt_screen, -1, true],
     [:render, 999, "x"]].each do |m, *args|
      mark(m)
      begin
        show(a.public_send(m, *args))
      rescue StandardError => e
        show([e.class, e.message])
      end
    end
    mark(:ids); show([a.create_renderer, Bubbletea::Program.new.create_renderer])
    [["x"], [2**70], [nil], [1.0], [1], [-1]].each do |args|
      mark(:key_name)
      begin
        show(Bubbletea.get_key_name(*args))
      rescue StandardError => e
        show([e.class, e.message])
      end
    end
    mark(:title); Bubbletea._set_window_title("héllo")
    mark(:clear); Bubbletea.clear_screen
    mark(:upstream); show(Bubbletea.upstream_version)
    mark(:tty); show(Bubbletea.tty?)
  RUBY

  def test_conformance_with_the_real_gem
    upstream = run_isolated(%(gem "bubbletea", "0.1.4"; require "bubbletea"\n#{CONFORMANCE}))
    skip "bubbletea 0.1.4 is not installed" unless upstream
    ours = run_isolated(%($LOAD_PATH.unshift(#{LIB.dump}); require "r2ui/compat/bubbletea"\n#{CONFORMANCE}))
    assert_equal upstream, ours
  end

  private

  def assert_raises_message(klass, message, &block)
    error = assert_raises(klass, &block)
    assert_equal message, error.message
  end

  # Runs code with our compat layer in a child whose stdin and stdout are the pty; returns its output.
  def run_child(code)
    script = %($LOAD_PATH.unshift(#{LIB.dump}); require "r2ui/compat/bubbletea"\n#{code})
    pid = Process.spawn(RbConfig.ruby, "-e", script, in: @slave, out: @slave, err: File::NULL)
    out = +"".b
    loop do
      out << drain
      next unless Process.waitpid(pid, Process::WNOHANG)

      pid = nil
      break
    end
    out << drain
  ensure
    if pid
      Process.kill(:KILL, pid)
      Process.wait(pid)
    end
  end

  # Output of code run outside bundler, or nil when it fails (the real gem missing).
  def run_isolated(code)
    run = lambda do
      Open3.capture2(RbConfig.ruby, "-e", code, stdin_data: "", chdir: Dir.tmpdir, err: File::NULL)
    end
    out, status = defined?(Bundler) ? Bundler.with_unbundled_env(&run) : run.call
    status.success? ? out.b : nil
  end
end
