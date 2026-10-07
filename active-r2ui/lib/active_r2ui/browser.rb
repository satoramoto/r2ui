# frozen_string_literal: true

module ActiveR2UI
  # The `bin/rails tui` program: the model list, and one model's table full screen after enter
  # (esc goes back). A Bubbletea model that hosts one R2UI::App per screen and passes every message
  # to the one showing; the list keeps its selection and stops fetching while a model is open.
  class Browser
    include Bubbletea::Model

    attr_reader :list, :current

    def initialize(registry = R2UI.registry, list: ModelList::NAME)
      @registry = registry
      @list = host(R2UI::App.new(registry, list))
      @current = @list
      @started = false
      @switched = false
      @size = nil
    end

    def run
      Bubbletea::Runner.new(self, **@list.program_options).run
    ensure
      stop
    end

    def stop = [@list, @current].uniq.each(&:stop)

    def init
      @started = true
      _, command = @current.init
      [self, command]
    end

    def update(message)
      @size = message if message.is_a?(Bubbletea::WindowSizeMessage)
      _, command = @current.update(message)
      [self, R2UI::Context.combine([command, navigate])]
    end

    def view
      @switched = false
      @current.view
    end

    def frame_due? = @switched || @current.frame_due?

    # --- for tests, like R2UI::App's ---

    def press(*keys) = keys.filter_map { |k| update(R2UI::Keys.message(k)).last }

    def frame(width, height) = @current.frame(width, height)

    private

    def host(app)
      app.store(:active_r2ui)[:browser] = true
      app
    end

    # Acts on what the extension's key handler asked for. Returns the new screen's init command.
    def navigate
      requests = @current.store(:active_r2ui)
      if (screen = requests.delete(:open)) then open(screen)
      elsif requests.delete(:back) && !@current.equal?(@list) then back
      end
    end

    def open(screen)
      @list.stop
      app = host(R2UI::App.new(@registry, screen))
      @current = app
      @switched = true
      return nil unless @started

      _, command = app.init
      app.update(@size) if @size
      command
    end

    def back
      @current.stop
      @current = @list
      @switched = true
      @list.feeds.each_value(&:start) if @started
      @list.update(@size) if @size
      nil
    end
  end
end
