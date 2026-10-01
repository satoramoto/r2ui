# frozen_string_literal: true

module R2UI
  # The running program, as a Bubbletea model: `init` starts the feeds and runs extension init
  # hooks, `update` routes each message (extension observers and handlers, components, then the
  # core keys) and returns their commands, `view` draws the dashboard. `run` runs it on r2ui's
  # Bubbletea engine (lib/r2ui/compat/bubbletea).
  class App
    include Bubbletea::Model

    FLASH_SECONDS = 3
    # Runner options; extensions change them with `program_options`.
    PROGRAM_OPTIONS = { alt_screen: true, fps: 20 }.freeze
    # Where the focused component takes keys among the `on` handlers: those with priority >= 50 run
    # before it, the rest after.
    COMPONENT_PRIORITY = 50
    # Table navigation keys, for help screens (`key_pairs`; the status bar leaves them out).
    NAVIGATION_PAIRS = [["↑/↓ j/k", "move"], ["pgup/pgdn", "page"], ["home/end", "first/last"]].freeze

    attr_reader :registry, :dashboard, :feeds, :focus, :state, :width, :height, :components

    def initialize(registry, name = nil)
      @registry = registry
      @dashboard = registry.screen(name)
      resources = @dashboard.panels.filter_map(&:resource).uniq.map { |r| registry.resource(r) }
      resources.filter_map(&:source_from).each { |s| registry.source(s) } # unknown sources fail here
      @sources = Sources.new(registry)
      @feeds = resources.to_h { |r| [r.name, Feed.new(r, sources: @sources)] }
      @states = @dashboard.panels.to_h do |p|
        [p, p.table && p.resource && PanelState.new(registry.resource(p.resource), p.table)]
      end
      @focus = initial_focus
      @renderer = Renderer.new(registry, @feeds, @states, draw_item: method(:draw_item))
      @mode = :normal
      @zoomed = false
      @state = {}
      @stores = Hash.new { |h, k| h[k] = {} }
      @components = []
      @width = 80
      @height = 24
      setup = Context.new(self)
      Extensions.hooks(:setup).each { |h| setup.call(h.block) }
    end

    # Runs on the terminal until quit. Feeds stop on every exit path.
    def run
      Bubbletea::Runner.new(self, **program_options).run
    ensure
      stop
    end

    def stop = @feeds.each_value(&:stop)

    # --- Bubbletea::Model ---

    def init
      ctx = Context.new(self)
      @feeds.each_value(&:start) unless @started
      @started = true
      start_components(ctx)
      Extensions.hooks(:init).each { |h| ctx.call(h.block) }
      after_update(ctx)
      [self, ctx.commands]
    end

    def update(message)
      ctx = Context.new(self, message)
      dispatch(ctx, message)
      sync_component_focus(ctx) if @components_started
      after_update(ctx)
      [self, ctx.commands]
    end

    # The frame as a String. Bubbletea calls it with no arguments (the terminal size). Tests can pass
    # `width:`/`height:` to draw at that size (frame_size hooks still apply) without sending a
    # WindowSizeMessage; view_override hooks run either way, so overlays show.
    def view(width: nil, height: nil)
      width, height = frame_size(width || @width, height || @height)
      ctx = Context.new(self)
      ctx.width = width
      ctx.height = height
      Extensions.hooks(:view_override).each do |h|
        text = ctx.call(h.block)
        return text.to_s if text
      end
      frame(width, height).ansi_lines.join("\n")
    end

    # --- for extensions and tests ---

    # Runner options: the defaults merged with every extension's `program_options`.
    def program_options
      ctx = Context.new(self)
      Extensions.hooks(:program_options).reduce(PROGRAM_OPTIONS) { |opts, h| opts.merge(ctx.call(h.block) || {}) }
    end

    # Private state for one extension.
    def store(name) = @stores[name.to_sym]

    def flash(text)
      @flash = text
      @flash_at = Time.now
      @flash_count = flash_count + 1
    end

    # How many times `flash` has been called (an action leaves a handler's own flash in place).
    def flash_count = @flash_count || 0

    # Rows under the selection of a table panel: `panel` is a panel name (Symbol), a DSL::Panel, or
    # nil for the focused panel. [] for a panel without a table or a selection. Reads the lines the
    # panel showed in the last drawn frame, so a test calls `frame` (or `view`) first.
    def selected_rows(panel = nil)
      panel = resolve_panel(panel)
      state = @states[panel]
      return [] unless state

      panel_lines(panel)[state.selected]&.rows || []
    end

    # Panel => Rect where each panel was drawn in the last frame.
    def panel_rects = @renderer.rects

    def focus=(panel)
      raise Error, "no panel #{panel.inspect}" unless @dashboard.panels.include?(panel)

      @focus = panel
    end

    # The hosted model for the component item named `name` (nil if none).
    def component(name)
      build_components
      @components.find { |c| c.name == name }&.model
    end

    # Gives key focus to the named component (blurring the others), or takes it away with `nil`:
    # e.g. esc in a text input hands keys back to the core while its panel stays focused.
    # Focus commands go on `ctx`. Panel focus changes move it to that panel's first focusable
    # component again.
    def focus_component(name, ctx = Context.new(self))
      target = name && @components.find { |c| c.focusable? && c.name == name }
      raise Error, "no focusable component #{name.inspect}" if name && !target

      @components.each { |c| set_component_focus(ctx, c, c.equal?(target)) if c.focusable? }
      ctx.commands
    end

    # The PanelState (scope, sort, search, selection, offset) of a table panel, or nil.
    def panel_state(panel) = @states[panel]

    # The lines a table panel showed in the last frame (Query::Line objects).
    def panel_lines(panel) = @renderer.lines.fetch(panel, [])

    # Status-bar hints as [key, label] pairs: extensions' first, then the core's.
    def hint_pairs(ctx = Context.new(self))
      extension_hints(ctx) + Renderer::HINT_PAIRS
    end

    # Every key as [key, label] pairs, for help screens: extensions' hints, the focused table
    # panel's resource actions, the navigation keys, then the core's status-bar hints.
    def key_pairs(ctx = Context.new(self))
      actions = state_for_focus ? resource.actions.map { |a| [a.key.to_s, a.label] } : []
      extension_hints(ctx) + actions + NAVIGATION_PAIRS + Renderer::HINT_PAIRS
    end

    def snapshot(width:, height:, ticks: 1)
      ticks.times do |i|
        sleep(@feeds.values.map(&:interval).min) if i.positive?
        @feeds.each_value(&:refresh!)
      end
      frame(width, height).plain_lines.join("\n")
    end

    # Feeds keys without a terminal, as if typed: core names (:up, "q") or Bubbletea names
    # ("ctrl+r"). Returns the commands they produced. Table keys and actions act on the lines the
    # focused panel showed in the last drawn frame, so call `frame` (or `view`) before pressing them.
    def press(*keys) = keys.filter_map { |k| update(Keys.message(k)).last }

    # [width, height] to draw at: the terminal size (or the size given), changed by extensions'
    # `frame_size`.
    def frame_size(width = @width, height = @height)
      ctx = Context.new(self)
      Extensions.hooks(:frame_size).reduce([width, height]) { |size, h| ctx.call(h.block, *size) }
    end

    # Canvas styles merged from every extension's `styles` hook (later ones win), or nil if none.
    def styles(ctx = Context.new(self))
      merged = Extensions.hooks(:styles).reduce({}) { |acc, h| acc.merge(ctx.call(h.block) || {}) }
      merged.empty? ? nil : merged
    end

    def frame(width, height)
      ctx = Context.new(self)
      build_components(ctx)
      @renderer.render(@dashboard, width:, height:, focus: @focus, zoomed: @zoomed, prompt: prompt(ctx),
                                   hints: hints(ctx), styles: styles(ctx))
    end

    private

    def dispatch(ctx, message)
      if message.is_a?(Bubbletea::WindowSizeMessage)
        @width = message.width
        @height = message.height
      end
      Extensions.hooks(:observe).each { |h| ctx.call(h.block, message) if h.match?(message) }
      key = message.is_a?(Bubbletea::KeyMessage) ? Keys.name(message) : nil
      return ctx.quit if key == :interrupt
      return core_key(ctx, key) if key && @mode != :normal

      broadcast_to_components(ctx, message) unless key
      before, after = Extensions.hooks(:on).partition { |h| h.priority >= COMPONENT_PRIORITY }
      return if handled?(ctx, before, message)
      return if key && focused_component_key(ctx, message, key)
      return if handled?(ctx, after, message)

      core_key(ctx, key) if key
    end

    def after_update(ctx) = Extensions.hooks(:after_update).each { |h| ctx.call(h.block) }

    # The dashboard's `focus :name` panel, else the first panel with a table, else the first panel.
    def initial_focus
      if (name = @dashboard.initial_focus)
        return @dashboard.panel(name) || raise(Error, "dashboard #{@dashboard.name}: focus #{name}: no such panel")
      end

      @dashboard.panels.find(&:table) || @dashboard.panels.first
    end

    def handled?(ctx, hooks, message) = hooks.any? { |h| h.match?(message) && ctx.handle(h.block, message) }

    def core_key(ctx, key)
      ctx.quit if handle(key, ctx) == :quit
    end

    # --- components ---

    # Builds the component models once (first frame or init, whichever comes first).
    def build_components(ctx = Context.new(self))
      return if @components_built

      @components_built = true
      specs = Extensions.hooks(:component)
      @dashboard.panels.each do |panel|
        panel.items.each do |item|
          spec = specs.find { |h| h.match?(item) }&.block
          next unless spec

          instance = Component::Instance.new(panel:, item:, spec:, focused: false)
          instance.model = ctx.call(spec.build, item)
          @components << instance
        end
      end
    end

    # Runs each model's `init` once, in App#init, and gives the focused panel's component focus.
    def start_components(ctx)
      build_components(ctx)
      return if @components_started

      @components_started = true
      @components.each do |instance|
        next unless instance.model.respond_to?(:init)

        instance.model, cmd = Component.split(instance.model, instance.model.init)
        ctx.command(cmd)
      end
      sync_component_focus(ctx)
    end

    def broadcast_to_components(ctx, message)
      @components.each { |c| update_component(ctx, c, message) }
    end

    def focused_component_key(ctx, message, key)
      return false if Component::RESERVED.include?(key)

      instance = @components.find { |c| c.focused && c.panel == @focus }
      return false unless instance

      update_component(ctx, instance, message)
      true
    end

    def set_component_focus(ctx, instance, want)
      return if instance.focused == want

      instance.focused = want
      cmd = want ? Component.focus(instance) : Component.blur(instance)
      ctx.command(cmd) if Context.command?(cmd)
    end

    def update_component(ctx, instance, message)
      instance.model, cmd = Component.split(instance.model, instance.model.update(message))
      ctx.command(cmd)
    end

    # When panel focus has changed: focus the first focusable component of the focused panel and
    # blur the rest.
    def sync_component_focus(ctx)
      return if @component_focus_panel.equal?(@focus) && @components_synced

      @components_synced = true
      @component_focus_panel = @focus
      active = @components.find { |c| c.focusable? && c.panel == @focus }
      @components.each { |c| set_component_focus(ctx, c, c.equal?(active)) if c.focusable? }
    end

    def draw_item(panel, item, width, height, rows = [])
      ctx = Context.new(self)
      ctx.panel = panel
      ctx.width = width
      ctx.height = height
      ctx.rows = rows
      drawer = Extensions.hooks(:panel_item).find { |h| h.match?(item) }
      return ctx.call(drawer.block, item) if drawer

      @components.find { |c| c.item.equal?(item) && c.panel == panel }&.model&.view
    end

    # --- core keys and status bar ---

    def state_for_focus = @states[@focus]

    # A DSL::Panel from a panel name, a panel, or nil (the focused panel).
    def resolve_panel(panel)
      case panel
      when nil then @focus
      when DSL::Panel then panel
      else @dashboard.panel(panel) || raise(Error, "no panel #{panel.inspect}")
      end
    end

    def extension_hints(ctx) = Extensions.hooks(:hints).flat_map { |h| ctx.call(h.block) || [] }

    def lines = @renderer.lines.fetch(@focus, [])

    def resource = @registry.resource(@focus.resource)

    def prompt(ctx)
      case @mode
      when :search then "/#{state_for_focus.search}▏"
      when Array then "#{@mode[1].label} #{@mode[2].size} #{@mode[2].size == 1 ? "row" : "rows"}? y/n"
      else
        return @flash if @flash && Time.now - @flash_at < FLASH_SECONDS

        Extensions.hooks(:status).each do |h|
          text = ctx.call(h.block)
          return text if text
        end
        nil
      end
    end

    def hints(ctx) = hint_pairs(ctx).map { |key, label| "#{key} #{label}" }.join("  ")

    def handle(key, ctx)
      return :quit if key == :interrupt

      case @mode
      when :search then search_key(key)
      when Array then confirm_key(key, ctx)
      else normal_key(key, ctx)
      end
    end

    def normal_key(key, ctx)
      case key
      when "q" then return :quit
      when :tab then cycle_focus(1)
      when :back_tab then cycle_focus(-1)
      when "z" then @zoomed = !@zoomed
      end
      table_key(key, ctx) if state_for_focus
      nil
    end

    def table_key(key, ctx)
      state = state_for_focus
      case key
      when :up, "k" then state.move(-1, lines.size)
      when :down, "j" then state.move(1, lines.size)
      when :page_up then state.move(-10, lines.size)
      when :page_down then state.move(10, lines.size)
      when :home then state.move(-lines.size, lines.size)
      when :end then state.move(lines.size, lines.size)
      when "[" then state.cycle_scope(-1)
      when "]" then state.cycle_scope(1)
      when "g" then state.cycle_grouping
      when "s" then state.cycle_sort
      when "S" then state.reverse_sort
      when "/" then @mode = :search
      when :enter, " " then state.toggle(lines[state.selected])
      else
        action = resource.actions.find { |a| a.key == key }
        start_action(action, ctx) if action
      end
    end

    def search_key(key)
      state = state_for_focus
      case key
      when :enter then @mode = :normal
      when :escape
        state.search = ""
        @mode = :normal
      when :backspace then state.search = state.search[0...-1]
      when String then state.search += key if key.match?(/[[:print:]]/)
      end
    end

    def start_action(action, ctx)
      rows = lines[state_for_focus.selected]&.rows
      return if rows.nil? || rows.empty?

      action.confirm ? @mode = [:confirm, action, rows] : run_action(action, rows, ctx)
    end

    def confirm_key(key, ctx)
      _, action, rows = @mode
      @mode = :normal
      run_action(action, rows, ctx) if key == "y"
    end

    # Runs the handler on the update's Context (so it can flash, read state, return or enqueue
    # commands): once per row, carrying on past failing rows, or once with every row for
    # `batch: true`. Flashes a summary unless the handler flashed something itself.
    def run_action(action, rows, ctx)
      flashes = flash_count
      summary = action.batch ? run_batch_action(action, rows, ctx) : run_row_action(action, rows, ctx)
      flash(summary) if flash_count == flashes
    end

    def run_batch_action(action, rows, ctx)
      ctx.call(action.handler, rows)
      "#{action.label}: #{rows.size} done"
    rescue StandardError => e
      "#{action.label} failed: #{e.message}"
    end

    def run_row_action(action, rows, ctx)
      errors = rows.filter_map do |row|
        ctx.call(action.handler, row)
        nil
      rescue StandardError => e
        e
      end
      return "#{action.label}: #{rows.size} done" if errors.empty?
      return "#{action.label} failed: #{errors.first.message}" if errors.size == rows.size

      "#{action.label}: #{rows.size - errors.size} done, #{errors.size} failed: #{errors.first.message}"
    end

    def cycle_focus(step)
      panels = @dashboard.panels
      return if panels.empty?

      @focus = panels[(panels.index(@focus) + step) % panels.size]
    end
  end
end
