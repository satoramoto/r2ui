# frozen_string_literal: true

# Pure-Ruby replacement for bubbletea 0.1.4's native extension (ext/bubbletea/{extension,program}.c
# over go/*.go): Bubbletea::Program and the Bubbletea module functions, with the C methods' return
# values and argument errors. Never loads the real gem.

require_relative "terminal"
require_relative "input_reader"
require_relative "input"
require_relative "renderer"
require_relative "ansi"

module R2UI
  module Compat
    module Tea
      # Ruby's C conversion macros, so arguments fail exactly as the extension's do.
      module CArgs
        INT_RANGE = (-2**31..2**31 - 1)
        FIXNUM_RANGE = (-2**62..2**62 - 1)
        ULL_MAX = 2**64 - 1

        module_function

        def type_name(value)
          case value
          when nil then "nil"
          when true then "true"
          when false then "false"
          else value.class.to_s
          end
        end

        # Check_Type(value, T_STRING) + StringValueCStr
        def cstr(value)
          raise TypeError, "wrong argument type #{type_name(value)} (expected String)" unless value.is_a?(String)
          raise ArgumentError, "string contains null byte" if value.include?("\0")

          value
        end

        # Check_Type(value, T_FIXNUM) + FIX2INT
        def fix2int(value)
          unless value.is_a?(Integer) && FIXNUM_RANGE.cover?(value)
            raise TypeError, "wrong argument type #{type_name(value)} (expected Integer)"
          end

          int_range(value)
        end

        # NUM2INT
        def num2int(value)
          raise TypeError, "no implicit conversion from nil to integer" if value.nil?

          int_range(to_integer(value))
        end

        # NUM2ULL
        def num2ull(value)
          raise TypeError, "no implicit conversion of nil into Integer" if value.nil?

          integer = to_integer(value)
          raise RangeError, "bignum out of range of unsigned long long" if integer > ULL_MAX || integer < -ULL_MAX

          integer & ULL_MAX
        end

        def to_integer(value)
          case value
          when Integer then value
          when Float
            raise RangeError, "float #{value} out of range of integer" if value.nan? || value.infinite?

            value.to_i
          else
            unless !value.is_a?(TrueClass) && !value.is_a?(FalseClass) && value.respond_to?(:to_int)
              raise TypeError, "no implicit conversion of #{type_name(value)} into Integer"
            end

            value.to_int
          end
        end

        def int_range(integer)
          return integer if INT_RANGE.cover?(integer)

          raise RangeError, "integer #{integer} too #{integer.positive? ? "big" : "small"} to convert to 'int'"
        end
      end

      # Program and renderer ids share one counter starting at 1, as Go's getNextID.
      @next_id = 1
      @next_id_lock = Mutex.new

      def self.next_id
        @next_id_lock.synchronize do
          id = @next_id
          @next_id += 1
          id
        end
      end

      # Renderers are global in upstream, keyed by id: any program may drive any id, and unknown ids
      # are ignored.
      @renderers = {}
      @renderers_lock = Mutex.new

      def self.register_renderer(renderer)
        id = next_id
        @renderers_lock.synchronize { @renderers[id] = renderer }
        id
      end

      def self.renderer(id) = @renderers_lock.synchronize { @renderers[id] }
    end
  end
end

module Bubbletea
  # The charmbracelet/x/ansi version upstream's Go build reports.
  def self.upstream_version = +"v0.8.0"

  def self.version
    format("bubbletea v%s (upstream charmbracelet/x/ansi %s) [r2ui pure Ruby]", VERSION, upstream_version)
  end

  def self.tty?
    $stdin.tty?
  rescue StandardError
    false
  end

  def self.clear_screen
    R2UI::Compat::Tea::Terminal.write(
      $stdout, R2UI::Compat::Tea::Terminal::ERASE_ENTIRE_SCREEN + R2UI::Compat::Tea::Terminal::CURSOR_HOME
    )
  end

  def self._set_window_title(title)
    title = R2UI::Compat::Tea::CArgs.cstr(title)
    R2UI::Compat::Tea::Terminal.write($stdout, R2UI::Compat::Tea::Terminal.window_title(title))
  end

  def self.get_key_name(key_type)
    R2UI::Compat::Tea::Input.key_name(R2UI::Compat::Tea::CArgs.fix2int(key_type))
  end

  class Program
    Tea = R2UI::Compat::Tea
    CArgs = Tea::CArgs
    private_constant :Tea, :CArgs

    # Like Go's tea_free_program, a collected program stops its reader. (Terminal modes it left on are
    # restored by Terminal's exit hook, which holds every dirty terminal.)
    def self.reader_finalizer(state) = proc { state[:reader]&.stop(wait: false) }
    private_class_method :reader_finalizer

    # Upstream takes no arguments and uses the process's stdin/stdout; the keywords let tests inject a pty.
    def initialize(input: $stdin, output: $stdout)
      @id = Tea.next_id
      @state = { terminal: Tea::Terminal.new(input, output), reader: nil }
      @pending_events = []
      ObjectSpace.define_finalizer(self, self.class.send(:reader_finalizer, @state))
    end

    def enter_raw_mode = terminal.enter_raw_mode
    def exit_raw_mode = terminal.exit_raw_mode
    def enter_alt_screen = terminal.enter_alt_screen
    def exit_alt_screen = terminal.exit_alt_screen
    def hide_cursor = terminal.hide_cursor
    def show_cursor = terminal.show_cursor
    def enable_mouse_cell_motion = terminal.enable_mouse_cell_motion
    def enable_mouse_all_motion = terminal.enable_mouse_all_motion
    def disable_mouse = terminal.disable_mouse
    def enable_bracketed_paste = terminal.enable_bracketed_paste
    def disable_bracketed_paste = terminal.disable_bracketed_paste
    def enable_report_focus = terminal.enable_report_focus
    def disable_report_focus = terminal.disable_report_focus
    def terminal_size = terminal.size

    def start_input_reader
      return true if @state[:reader]

      @state[:reader] = Tea::InputReader.new(terminal.input).start
      @state[:decoder] = Tea::Input::Decoder.new
      true
    rescue StandardError
      false
    end

    # Stops consuming input; like Go dropping the reader, anything still buffered is discarded.
    def stop_input_reader
      reader = @state[:reader]
      return unless reader

      reader.stop
      @state[:reader] = nil
      @state[:decoder] = nil
      @pending_events.clear
      nil
    end

    def read_raw_input(timeout_ms)
      timeout_ms = CArgs.num2int(timeout_ms)
      @state[:reader]&.pop(timeout_ms)
    end

    # Next decoded event as a Hash, or nil on timeout. Unlike upstream, which decodes only the first
    # event of each chunk, the rest of a chunk's events stay queued for the following calls.
    def poll_event(timeout_ms)
      timeout_ms = CArgs.num2int(timeout_ms)
      reader = @state[:reader]
      return nil unless reader
      return @pending_events.shift unless @pending_events.empty?

      chunk = reader.pop(timeout_ms)
      return nil unless chunk

      @pending_events.concat(@state[:decoder].feed(chunk))
      @pending_events.shift
    end

    def create_renderer = Tea.register_renderer(Tea::Renderer.new(terminal.output))

    def render(renderer_id, view)
      view = CArgs.cstr(view)
      Tea.renderer(CArgs.num2ull(renderer_id))&.render(view)
      nil
    end

    def renderer_set_size(renderer_id, width, height)
      id = CArgs.num2ull(renderer_id)
      width = CArgs.num2int(width)
      height = CArgs.num2int(height)
      Tea.renderer(id)&.set_size(width, height)
      nil
    end

    def renderer_set_alt_screen(renderer_id, enabled)
      Tea.renderer(CArgs.num2ull(renderer_id))&.alt_screen = enabled ? true : false
      nil
    end

    def renderer_clear(renderer_id)
      Tea.renderer(CArgs.num2ull(renderer_id))&.clear
      nil
    end

    def string_width(str) = Tea::ANSI.string_width(CArgs.cstr(str))

    private

    def terminal = @state[:terminal]
  end
end
