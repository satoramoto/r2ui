# frozen_string_literal: true

require "test_helper"
require "open3"

# The extension point (R2UI.extension) and the app's message routing on the Bubbletea model.
class ExtensionTest < Minitest::Test
  Ping = Class.new(Bubbletea::Message)
  Bump = Data.define(:name)

  # A Bubbletea-style model, as bubbles components are.
  class FakeInput
    attr_reader :value, :log

    def initialize = (@value = +""; @log = [])
    def init = [self, :init_command]
    def focus = (@log << :focus; nil)
    def blur = @log << :blur
    def view = "[#{@value}]"

    def update(message)
      @log << message.class
      @value << message.char if message.is_a?(Bubbletea::KeyMessage) && message.runes?
      [self, nil]
    end
  end

  InputItem = Data.define(:name)

  def setup
    R2UI.reset!
    @extensions = []
  end

  def teardown = @extensions.each { |name| R2UI::Extensions.remove(name) }

  def extension(name, &)
    @extensions << name
    R2UI.extension(name, &)
  end

  def app = @app ||= R2UI::App.new(R2UI.registry)

  def test_dsl_keyword_declares_on_the_dashboard
    extension(:test_bump) do
      dsl(:dashboard) { def bump(name) = declare(:bump, Bump.new(name)) }
    end
    dashboard = R2UI.dashboard { bump :a; bump :b; row { panel(:p, resource: nil) { view { "" } } } }

    assert_equal [Bump.new(:a), Bump.new(:b)], dashboard.declared(:bump)
    assert_equal [], dashboard.declared(:nothing)
  end

  def test_taken_keyword_is_an_error_and_remove_takes_it_back
    error = assert_raises(R2UI::Error) { extension(:test_clash) { dsl(:dashboard) { def row = nil } } }
    assert_match(/already has row/, error.message)
    assert_nil R2UI::Extensions[:test_clash], "a failed extension is not registered"

    extension(:test_gone) { dsl(:panel) { def gone = item(:gone) } }
    R2UI::Extensions.remove(:test_gone)
    refute R2UI::DSL::Dashboard::PanelBuilder.method_defined?(:gone)
  end

  def test_on_handlers_run_by_priority_and_can_pass
    seen = []
    extension(:test_low) { on(Ping) { seen << :low } }
    extension(:test_high) { on(Ping, priority: 10) { seen << :high; pass } }
    extension(:test_observer) { observe(Ping) { seen << :observed } }
    R2UI.dashboard { row { panel(:p, resource: nil) { view { "" } } } }

    app.update(Ping.new)

    assert_equal %i[observed high low], seen
  end

  def test_handlers_return_commands_and_helpers_are_shared
    extension(:test_helpers) do
      helpers { def shout(text) = flash(text.upcase) }
      on(Ping) { shout "hi"; command(Bubbletea.tick(1) { nil }); Bubbletea.quit }
    end
    R2UI.dashboard { row { panel(:p, resource: nil) { view { "" } } } }

    _, command = app.update(Ping.new)

    assert_equal [Bubbletea::TickCommand, Bubbletea::QuitCommand], command.commands.map(&:class)
    assert_match(/HI/, app.frame(40, 4).plain_lines.last)
  end

  def test_extension_keys_run_before_core_keys_but_not_during_search
    extension(:test_keys) do
      on(->(m) { m.is_a?(Bubbletea::KeyMessage) && m.to_s == "s" }) { state[:s] = state[:s].to_i + 1 }
    end
    Fixtures.define_processes
    R2UI.dashboard { row { panel :process } }
    app.frame(80, 10)

    app.press("s")
    assert_equal 1, app.state[:s]
    assert_match(/sort: Cpu▼/, app.frame(80, 10).plain_lines.last, "core sort key didn't run")

    app.press("/", "s")
    assert_equal 1, app.state[:s], "search prompt takes the key"
    assert_match(%r{/s▏}, app.frame(80, 10).plain_lines.last)
  end

  def test_ctrl_c_and_q_quit
    R2UI.dashboard { row { panel(:p, resource: nil) { view { "" } } } }

    assert_kind_of Bubbletea::QuitCommand, app.press("ctrl+c").first
    assert_kind_of Bubbletea::QuitCommand, app.press("q").first
  end

  def test_window_size_sets_the_frame_and_frame_size_hooks_change_it
    R2UI.dashboard { row { panel(:p, resource: nil) { view { "#{width}x#{height}" } } } }
    app.update(Bubbletea::WindowSizeMessage.new(width: 30, height: 6))
    assert_equal 6, app.view.lines.size
    assert_match(/28x3/, app.view)

    extension(:test_inline) { frame_size { |w, _h| [w, 4] } }
    assert_equal 4, app.view.lines.size
  end

  def test_hints_status_styles_and_program_options
    extension(:test_bar) do
      hints { [["r", "refresh"]] }
      status { "all good" }
      styles { { focus: "31" } }
      program_options { { mouse_cell_motion: true } }
    end
    R2UI.dashboard { row { panel(:p, resource: nil) { view { "" } } } }

    status = app.frame(120, 4).plain_lines.last
    assert_match(/all good/, status)
    assert_match(/r refresh  tab panel/, status)
    assert_match(/\e\[0;31m╭/, app.frame(120, 4).ansi_lines.first)
    assert_equal({ alt_screen: true, fps: 20, mouse_cell_motion: true }, app.program_options)
  end

  def test_setup_seeds_state_and_view_override_replaces_the_dashboard
    extension(:test_whole) do
      dsl(:dashboard) { def whole(&block) = declare(:whole, block) }
      setup { state[:greeting] = "hi" }
      view_override { (block = dashboard.declared(:whole).first) && call(block) }
    end
    R2UI.dashboard { whole { "#{state[:greeting]} #{width}x#{height}" } }
    app.update(Bubbletea::WindowSizeMessage.new(width: 30, height: 6))

    assert_equal "hi 30x6", app.view
    assert_nil app.press(:tab, :back_tab).first, "focus keys are harmless with no panels"
  end

  def test_after_update_runs_after_init_and_each_update_with_its_commands
    seen = []
    extension(:test_after) do
      on(Ping) { state[:pinged] = true }
      after_update { seen << state[:pinged]; command(Bubbletea.set_window_title("t")) if state[:pinged] }
    end
    R2UI.dashboard { row { panel(:p, resource: nil) { view { "" } } } }

    _, first = app.init
    _, command = app.update(Ping.new)

    assert_equal [nil, true], seen
    assert_nil first
    assert_kind_of Bubbletea::SetWindowTitleCommand, command
  ensure
    app.stop
  end

  def test_components_draw_before_init_as_in_a_snapshot
    extension(:test_snap) do
      dsl(:panel) { def input(name) = item(InputItem.new(name)) }
      component(InputItem, focusable: true) { |_item| FakeInput.new }
    end
    R2UI.dashboard { row { panel(:form, resource: nil) { input :name } } }

    assert_match(/│\[\]/, R2UI.snapshot(width: 30, height: 5))
    assert_equal [], app.component(:name).log, "no init or focus without a running program"
  end

  def test_require_r2ui_leaves_the_load_path_alone
    out, status = Open3.capture2e(RbConfig.ruby, "-I#{File.expand_path("../lib", __dir__)}", "-e", <<~RUBY)
      require "r2ui"
      abort "drop_in loaded" if $LOAD_PATH.any? { |p| p.end_with?("compat/load_path") }
      R2UI::Component.require_bubbles!
      abort "real gem loaded" if $LOADED_FEATURES.grep(%r{/gems/(bubbletea|lipgloss)-}).any?
      puts Bubbles::Spinner.new.view
    RUBY
    assert status.success?, out
    assert_equal "|\n", out
  end

  def test_unknown_panel_item_is_an_error
    R2UI.dashboard do
      row { panel(:p, resource: nil) { item(:mystery) } }
    end

    error = assert_raises(R2UI::Error) { app.frame(40, 5) }
    assert_match(/no extension draws Symbol/, error.message)
  end

  def test_panel_without_resource_or_items_is_an_error
    error = assert_raises(R2UI::Error) { R2UI.dashboard { row { panel :empty, resource: nil } } }
    assert_match(/nothing to show/, error.message)
  end

  def test_components_get_built_focused_and_fed_messages
    extension(:test_input) do
      dsl(:panel) { def input(name) = item(InputItem.new(name)) }
      component(InputItem, focusable: true) { |_item| FakeInput.new }
      on(->(m) { m.is_a?(Bubbletea::KeyMessage) && m.to_s == "h" }) { state[:bound] = true }
    end
    Fixtures.define_processes
    R2UI.dashboard do
      row { panel(:form, resource: nil) { input :name } }
      row { panel :process }
    end
    app.focus = app.dashboard.panels.first

    _, command = app.init
    input = app.component(:name)
    assert_equal :init_command, command
    assert_equal [:focus], input.log

    app.press("h", "q", "i")
    assert_equal "hqi", input.value, "a focused component takes q too"
    assert_nil app.state[:bound], "a focused component beats ordinary bindings"
    assert_match(/│\[hqi\]/, app.frame(40, 10).plain_lines.join("\n"))

    app.update(Ping.new)
    assert_equal Ping, input.log.last, "non-key messages reach every component"

    app.press(:tab)
    assert_equal :blur, input.log.last, "tab moves panel focus; the component is blurred"
    app.press("x")
    assert_equal "hqi", input.value, "keys go to the core once its panel loses focus"

    app.press(:back_tab)
    assert_equal :focus, input.log.last, "panel focus back: the component is focused again"
    app.focus_component(nil)
    assert_equal :blur, input.log.last
    assert_kind_of Bubbletea::QuitCommand, app.press("q").first, "a blurred component leaves keys to the core"
  ensure
    app.stop
  end
end
