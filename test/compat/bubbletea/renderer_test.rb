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

      @available = !Gem::Specification.find_all_by_name("bubbletea", "0.1.4").empty? ||
                   ruby(%(gem "bubbletea", "0.1.4"; require "bubbletea")).last.success?
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

    def ruby(code, *args)
      call = -> { Open3.capture2e(RbConfig.ruby, "-e", code, *args) }
      defined?(Bundler) ? Bundler.with_unbundled_env(&call) : call.call
    end
  end
end
