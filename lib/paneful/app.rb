# frozen_string_literal: true

module Paneful
  # The running program: feeds, panel focus, key handling and the draw loop.
  class App
    FRAME = 0.25
    FLASH_SECONDS = 3

    def initialize(registry, name = nil)
      @registry = registry
      @dashboard = registry.screen(name)
      resources = @dashboard.panels.map(&:resource).uniq.map { |r| registry.resource(r) }
      @feeds = resources.to_h { |r| [r.name, Feed.new(r)] }
      @states = @dashboard.panels.to_h do |p|
        [p, p.table && PanelState.new(registry.resource(p.resource), p.table)]
      end
      @focus = @dashboard.panels.find(&:table) || @dashboard.panels.first
      @renderer = Renderer.new(registry, @feeds, @states)
      @mode = :normal
      @zoomed = false
    end

    def run
      terminal = Terminal.new
      @resized = false
      previous_winch = Signal.trap("WINCH") { @resized = true }
      @feeds.each_value(&:start)
      terminal.open do
        loop do
          width, height = terminal.size
          terminal.clear if @resized
          @resized = false
          terminal.draw(frame(width, height))
          break if terminal.read_keys(FRAME).any? { |key| handle(key) == :quit }
        end
      end
    ensure
      @feeds.each_value(&:stop)
      Signal.trap("WINCH", previous_winch || "DEFAULT")
    end

    def snapshot(width:, height:, ticks: 1)
      ticks.times do |i|
        sleep(@feeds.values.map { |f| f.resource.interval }.min) if i.positive?
        @feeds.each_value(&:refresh!)
      end
      frame(width, height).plain_lines.join("\n")
    end

    # Exposed for tests: feed keys without a terminal.
    def press(*keys) = keys.each { |k| handle(k) }

    def frame(width, height)
      @renderer.render(@dashboard, width:, height:, focus: @focus, zoomed: @zoomed, prompt:)
    end

    private

    def state = @states[@focus]

    def lines = @renderer.lines.fetch(@focus, [])

    def resource = @registry.resource(@focus.resource)

    def prompt
      case @mode
      when :search then "/#{state.search}▏"
      when Array then "#{@mode[1].label} #{@mode[2].size} #{@mode[2].size == 1 ? "row" : "rows"}? y/n"
      else @flash if @flash && Time.now - @flash_at < FLASH_SECONDS
      end
    end

    def handle(key)
      return :quit if key == :interrupt

      case @mode
      when :search then search_key(key)
      when Array then confirm_key(key)
      else normal_key(key)
      end
    end

    def normal_key(key)
      case key
      when "q" then return :quit
      when :tab then cycle_focus(1)
      when :back_tab then cycle_focus(-1)
      when "z" then @zoomed = !@zoomed
      end
      table_key(key) if state
      nil
    end

    def table_key(key)
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
        start_action(action) if action
      end
    end

    def search_key(key)
      case key
      when :enter then @mode = :normal
      when :escape
        state.search = ""
        @mode = :normal
      when :backspace then state.search = state.search[0...-1]
      when String then state.search += key if key.match?(/[[:print:]]/)
      end
    end

    def start_action(action)
      rows = lines[state.selected]&.rows
      return if rows.nil? || rows.empty?

      action.confirm ? @mode = [:confirm, action, rows] : run_action(action, rows)
    end

    def confirm_key(key)
      _, action, rows = @mode
      @mode = :normal
      run_action(action, rows) if key == "y"
    end

    def run_action(action, rows)
      rows.each { |row| action.handler.call(row) }
      flash("#{action.label}: #{rows.size} done")
    rescue StandardError => e
      flash("#{action.label} failed: #{e.message}")
    end

    def flash(text)
      @flash = text
      @flash_at = Time.now
    end

    def cycle_focus(step)
      panels = @dashboard.panels
      @focus = panels[(panels.index(@focus) + step) % panels.size]
    end
  end
end
