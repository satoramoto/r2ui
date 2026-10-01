# frozen_string_literal: true

module R2UI
  # What a hook or user block runs on (instance_exec). Holds the running app and the commands the
  # block enqueues; the app batches them into the Bubbletea command its init/update returns.
  #
  # Core helpers are below; extensions add more with `helpers do ... end`. Command helpers enqueue
  # with `command(...)` and return the command, so a block can also just return one.
  class Context
    attr_reader :app, :message
    # Set while drawing a panel item.
    attr_accessor :panel, :width, :height
    # While drawing a panel item: the panel's resource rows ([] for a panel without a resource).
    attr_accessor :rows

    def initialize(app, message = nil)
      @app = app
      @message = message
      @commands = []
    end

    def self.command?(value) = value.is_a?(Bubbletea::Command) || value.is_a?(Proc)

    # nil, one command, or a batch of several.
    def self.combine(commands)
      commands = commands.compact
      commands.size <= 1 ? commands.first : Bubbletea.batch(*commands)
    end

    # The app's user state: a Hash any block may read and write.
    def state = app.state

    # Private runtime state for one extension (timers it scheduled, component models, ...).
    def store(name) = app.store(name)

    def dashboard = app.dashboard

    # The focused panel (a DSL::Panel).
    def focus = app.focus

    # While drawing a panel item: the panel's first row (its record), or nil.
    def record = rows&.first

    # Rows under the selection of a table panel (a name or DSL::Panel; nil: the focused panel),
    # [] if none. From the last drawn frame (App#selected_rows).
    def selected_rows(panel = nil) = app.selected_rows(panel)

    # The hosted model of the component item named `name` (see R2UI::Component), or nil.
    def component(name) = app.component(name)

    # Moves key focus to the named component, or away from all with nil (App#focus_component).
    def focus_component(name)
      app.focus_component(name, self)
      nil
    end

    # Shows text on the status bar for a few seconds.
    def flash(text) = app.flash(text)

    def quit = command(Bubbletea.quit)

    # Enqueues a Bubbletea command (or a Proc, run in the background). Returns it.
    def command(cmd)
      @commands << cmd if cmd && @commands.none? { |c| c.equal?(cmd) }
      cmd
    end

    # Inside an `on` handler: decline the message, so lower-priority handlers and the core see it.
    def pass = throw(:r2ui_pass)

    # Runs `block` here; a returned command is enqueued too. Returns the block's value.
    def call(block, *args)
      result = instance_exec(*args, &block)
      (result.is_a?(Array) ? result : [result]).each { |r| command(r) if Context.command?(r) }
      result
    end

    # Runs an `on` handler: true if it consumed the message (didn't `pass`).
    def handle(block, message)
      catch(:r2ui_pass) do
        call(block, message)
        return true
      end
      false
    end

    # The enqueued commands as one Bubbletea command (nil if none).
    def commands = Context.combine(@commands)
  end
end
