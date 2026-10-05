# frozen_string_literal: true

require "test_helper"
require "open3"
require "tempfile"
require "rbconfig"
require "stringio"
require "r2ui/compat/bubbletea/renderer"

# Expected bytes were recorded from the real bubbletea 0.1.4 gem's Go renderer
# (Program#render etc., which write to fd 1). The differential test replays
# the scenarios, plus more, against the live gem when it is installed.
class CompatTeaRendererTest < Minitest::Test
  Renderer = R2UI::Compat::Tea::Renderer

  # Records every write and flush so tests can check one write per call.
  class RecordingIO
    attr_reader :writes, :flushes

    def initialize
      @writes = []
      @flushes = 0
    end

    def write(bytes)
      @writes << bytes.b
      bytes.bytesize
    end

    def flush
      @flushes += 1
      self
    end
  end

  INLINE = [
    [[:render, "a\nb\nc"], "\ra\e[K\r\nb\e[K\r\nc\e[K\r"],
    [[:render, "a\nb\nc"], ""],
    [[:render, "x\ny\nz\nw"], "\e[2A\rx\e[K\r\ny\e[K\r\nz\e[K\r\nw\e[K\r"],
    [[:render, "short"], "\e[3A\rshort\e[K\r\n\e[2K\r\n\e[2K\r\n\e[2K\e[3A\r"],
    [[:clear], "\e[2J\e[H"],
    [[:render, "after"], "\rafter\e[K\r"],
    [[:render, ""], "\r\e[K\r"],
    [[:render, "a\nb\n"], "\ra\e[K\r\nb\e[K\r\n\e[K\r"]
  ].freeze

  ALT_SCREEN = [
    [[:alt, true], ""],
    [[:render, "one\ntwo\nthree"], "\e[Hone\e[K\r\ntwo\e[K\r\nthree\e[K"],
    [[:render, "1"], "\e[H1\e[K\r\n\e[2K\r\n\e[2K"],
    [[:render, "1\n2\n3\n4\n5"], "\e[H1\e[K\r\n2\e[K\r\n3\e[K\r\n4\e[K\r\n5\e[K"],
    [[:clear], "\e[2J\e[H"],
    [[:render, "x"], "\e[Hx\e[K"]
  ].freeze

  SIZED = [
    [[:size, 10, 2], ""],
    [[:render, "l1\nl2\nl3\nl4"], "\rl3\e[K\r\nl4\e[K\r"],
    [[:render, "日本語テキストです\n\e[31mred long line here\e[0m"],
     "\e[A\r日本語テキ\e[K\r\n\e[31mred long l\e[0m\e[K\r"],
    [[:render, "x"], "\e[A\rx\e[K\r\n\e[2K\e[A\r"]
  ].freeze

  def test_inline_frames_match_recorded_upstream
    assert_frames INLINE
  end

  def test_alt_screen_frames_match_recorded_upstream
    assert_frames ALT_SCREEN
  end

  def test_size_keeps_last_lines_and_truncates_match_recorded_upstream
    assert_frames SIZED
  end

  def test_each_call_is_one_write_and_flush
    io = RecordingIO.new
    renderer = Renderer.new(io)
    renderer.render("a\nb")
    renderer.render("a\nb")
    renderer.clear
    assert_equal ["\ra\e[K\r\nb\e[K\r", "\e[2J\e[H"], io.writes
    assert_equal 2, io.flushes
  end

  # r2ui addition: DEC 2026 synchronized output around each emitted frame, only when asked.
  def test_synchronized_wraps_each_emitted_frame
    io = RecordingIO.new
    renderer = Renderer.new(io, synchronized: true)
    renderer.render("a\nb")
    renderer.render("a\nb")
    renderer.render("c")
    assert_equal ["\e[?2026h\ra\e[K\r\nb\e[K\r\e[?2026l",
                  "\e[?2026h\e[A\rc\e[K\r\n\e[2K\e[A\r\e[?2026l"], io.writes, "an unchanged frame writes nothing"

    plain = RecordingIO.new
    renderer = Renderer.new(plain)
    renderer.render("a")
    renderer.synchronized = true
    renderer.render("b")
    assert_equal ["\ra\e[K\r", "\e[?2026h\rb\e[K\r\e[?2026l"], plain.writes, "off by default, as upstream"
  end

  # r2ui addition: line_diff writes only the lines that changed, in the alt screen.
  def diffing(io, width: 10, height: 5, **options)
    renderer = Renderer.new(io, line_diff: true, **options)
    renderer.set_size(width, height)
    renderer.alt_screen = true
    renderer
  end

  def test_line_diff_writes_only_changed_lines
    io = RecordingIO.new
    renderer = diffing(io)
    renderer.render("a\nb\nc\nd")
    renderer.render("a\nb\nc\nd")
    renderer.render("a\nB\nc\nd")
    renderer.render("x\nB\nc\nD")
    renderer.render("x\nY\nZ\nD")
    assert_equal ["\e[Ha\e[K\r\nb\e[K\r\nc\e[K\r\nd\e[K", "\e[2HB\e[K", "\e[Hx\e[K\e[4HD\e[K",
                  "\e[2HY\e[K\r\nZ\e[K"], io.writes, "an unchanged frame writes nothing"
    assert_equal io.writes.size, io.flushes
  end

  def test_line_diff_truncates_wide_changed_lines_and_keeps_sync
    io = RecordingIO.new
    renderer = diffing(io, width: 4, synchronized: true)
    renderer.render("ab\ncd")
    renderer.render("ab\n日本語テキ")
    renderer.render("ab\n\e[31mredred\e[0m")
    assert_equal ["\e[2H日本\e[K".b, "\e[2H\e[31mredr\e[0m\e[K"], io.writes.drop(1).map { |w| w.delete_prefix("\e[?2026h").delete_suffix("\e[?2026l") }
    assert io.writes.all? { |w| w.start_with?("\e[?2026h") && w.end_with?("\e[?2026l") }
  end

  def test_line_diff_redraws_whole_after_anything_that_may_disturb_the_screen
    full = "\e[Ha\e[K\r\nb\e[K"
    {
      "a line-count change" => ->(r) { r.render("a\nb\nc") && nil },
      "a resize" => ->(r) { r.set_size(11, 5) },
      "clear" => ->(r) { r.clear },
      "alt_screen=" => ->(r) { r.alt_screen = true }
    }.each do |name, disturb|
      io = RecordingIO.new
      renderer = diffing(io)
      renderer.render("x\nb")
      disturb.call(renderer)
      io.writes.clear
      renderer.render("a\nb")
      expected = name == "a line-count change" ? full + "\r\n\e[2K" : full
      assert_equal [expected], io.writes, name
    end

    io = RecordingIO.new
    renderer = diffing(io)
    renderer.render("x\nb")
    renderer.set_size(10, 5)
    renderer.render("a\nb")
    assert_equal "\e[Ha\e[K", io.writes.last, "a set_size without a change keeps the diff"
  end

  def test_line_diff_off_or_inline_writes_what_upstream_does
    [Renderer.new(StringIO.new(+"".b)), Renderer.new(StringIO.new(+"".b), line_diff: true)].each do |renderer|
      renderer.set_size(10, 5)
      renderer.render("a\nb")
      renderer.render("a\nc")
      assert_equal "\ra\e[K\r\nb\e[K\r\e[A\ra\e[K\r\nc\e[K\r", renderer.instance_variable_get(:@output).string
    end
    io = StringIO.new(+"".b)
    renderer = Renderer.new(io)
    renderer.set_size(10, 5)
    renderer.alt_screen = true
    renderer.render("a\nb")
    renderer.render("a\nc")
    assert_equal "\e[Ha\e[K\r\nb\e[K\e[Ha\e[K\r\nc\e[K", io.string
  end

  # The diffing renderer leaves the same screen as the whole-frame one, frame after frame.
  def test_line_diff_screens_match_full_redraws
    require_relative "../../../conformance/lib/vt"
    rng = Random.new(42)
    words = ["", "ok", "日本語", "\e[1;32mgreen\e[0m", "a much longer line than the width", "x" * 12, "é"]
    rows = 6
    frame = Array.new(rows) { words.sample(random: rng) }
    frames = Array.new(80) do |n|
      count = n % 17 == 16 ? rows - 1 : rows # now and then one line fewer
      frame = Array.new(count) { |i| rng.rand < 0.2 ? words.sample(random: rng) : (frame[i] || "") }
      frame.join("\n")
    end

    screens = [false, true].map do |diff|
      io = StringIO.new(+"".b)
      renderer = Renderer.new(io, line_diff: diff)
      renderer.set_size(12, rows)
      renderer.alt_screen = true
      vt = Conformance::VT.new(cols: 12, rows:)
      vt.feed("\e[?1049h")
      frames.each_with_index.map do |view, n|
        if n == 40
          vt.resize(14, rows)
          renderer.set_size(14, rows)
        end
        renderer.render(view)
        vt.feed(io.string)
        io.truncate(0)
        io.rewind
        vt.snapshot
      end
    end
    assert_equal screens[0], screens[1]
    refute_equal screens[1].first, screens[1].last, "the frames changed the screen"
  end

  # Upstream ignores stdout write errors, so a hung-up or closed terminal
  # never raises out of render or clear.
  def test_ignores_write_errors_after_hangup
    [Errno::EIO, Errno::EPIPE, IOError].each do |error|
      io = Object.new
      io.define_singleton_method(:write) { |_| raise error }
      io.define_singleton_method(:flush) { self }
      renderer = Renderer.new(io)
      assert_nil renderer.render("a\nb")
      assert_nil renderer.clear
    end

    reader, writer = IO.pipe
    writer.close
    assert_nil Renderer.new(writer).render("a")
  ensure
    reader&.close
  end

  def test_rejects_null_bytes_like_the_c_glue
    assert_raises(ArgumentError) { Renderer.new(StringIO.new).render("a\0b") }
  end

  SCENARIOS = [
    INLINE.map(&:first),
    ALT_SCREEN.map(&:first),
    SIZED.map(&:first),
    [[:render, "😀 emoji\n👨‍👩‍👧‍👦 family\n🇯🇵🇺🇸 flags\n❤️ heart"], [:size, 6, 0], [:render, "😀 emoji\n👨‍👩‍👧‍👦 family\n🇯🇵🇺🇸 flags"],
     [:render, "ééééééé combining"]],
    [[:size, 8, 3], [:alt, true], [:render, "\e]8;;https://example.com\e\\a long hyperlink\e]8;;\e\\\nline2\nline3\nline4"],
     [:render, "\e[1;32mgreen bold text\e[0m"], [:render, "\e[1;32mgreen bold text\e[0m"], [:alt, false],
     [:render, "back inline\nsecond"], [:clear], [:render, "中文字符和English混合\n한국어 텍스트"]],
    [[:render, "1\n2\n3\n4\n5\n6"], [:size, 0, 3], [:render, "a\nb\nc\nd\ne"], [:render, "a\nb\nc\nd\ne"],
     [:render, "only"], [:size, 4, 0], [:render, "wide line\nok\nｈｅｌｌｏ"], [:render, ""], [:render, "\n\n"]]
  ].freeze

  def test_frames_differential_against_real_gem
    skip "bubbletea 0.1.4 not installed" unless RealTea.available?

    expected = RealTea.run(SCENARIOS.map { |ops| [:frames, ops] })
    SCENARIOS.zip(expected).each do |ops, frames|
      assert_frames ops.zip(frames)
    end
  end

  private

  def assert_frames(steps)
    io = StringIO.new(+"".b)
    renderer = Renderer.new(io)
    steps.each do |(op, *args), expected|
      before = io.string.bytesize
      case op
      when :size then renderer.set_size(*args)
      when :alt then renderer.alt_screen = args[0]
      when :render then renderer.render(args[0])
      when :clear then renderer.clear
      end
      assert_equal expected.b, io.string.byteslice(before..), "#{op} #{args.inspect}"
    end
  end

  # Runs jobs against the real gem in a separate Ruby process (its native
  # extension must never load into this one).
  module RealTea
    SCRIPT = <<~'RUBY'
      require "bubbletea"
      jobs = Marshal.load(File.binread(ARGV[0]))
      cap = ARGV[2]
      STDOUT.reopen(cap, "wb")
      program = Bubbletea::Program.new
      out = jobs.map do |kind, arg|
        case kind
        when :width then program.string_width(arg)
        when :frames
          id = program.create_renderer
          arg.map do |op, *a|
            before = File.size(cap)
            case op
            when :size then program.renderer_set_size(id, *a)
            when :alt then program.renderer_set_alt_screen(id, a[0])
            when :render then program.render(id, a[0])
            when :clear then program.renderer_clear(id)
            end
            File.binread(cap).byteslice(before..)
          end
        end
      end
      File.binwrite(ARGV[1], Marshal.dump(out))
    RUBY

    module_function

    def available?
      return @available if defined?(@available)

      @available = !env.nil?
    end

    # Where the real gem loads: in this bundle (as the parent finds gems), else outside it.
    def env
      return @env if defined?(@env)

      @env = %i[bundled unbundled].find do |mode|
        ruby_in(mode, %(gem "bubbletea", "0.1.4"; require "bubbletea")).last.success?
      end
    end

    def run(jobs)
      Tempfile.create("tea-jobs") do |input|
        Tempfile.create("tea-out") do |output|
          Tempfile.create("tea-stdout") do |captured|
            input.binmode.write(Marshal.dump(jobs))
            input.close
            log, status = ruby(SCRIPT, input.path, output.path, captured.path)
            raise "real bubbletea failed: #{log}" unless status.success?

            Marshal.load(File.binread(output.path))
          end
        end
      end
    end

    def ruby(code, *args) = ruby_in(env || :unbundled, code, *args)

    def ruby_in(mode, code, *args)
      call = -> { Open3.capture2e(RbConfig.ruby, "-e", code, *args) }
      mode == :unbundled && defined?(Bundler) ? Bundler.with_unbundled_env(&call) : call.call
    end
  end
end
