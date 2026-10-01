# frozen_string_literal: true

module R2UI
  # One capability in one file. An extension registers everything it needs without editing shared
  # files: DSL keywords on the builders, helpers for handler blocks, Bubbletea init/update hooks,
  # panel item drawers, status-bar hints and program options. Files in lib/r2ui/ext/ load
  # automatically. See docs/dsl.md and lib/r2ui/ext/every.rb (the reference extension).
  #
  #   R2UI.extension :every do
  #     dsl(:dashboard) { def every(seconds, &block) = declare(:every, ...) }
  #     init { dashboard.declared(:every).each { |t| command(tick_for(t)) } }
  #     on(Tick) { |tick| ... }
  #   end
  #
  # Every hook block runs on a Context (instance_exec), so it can call the core helpers
  # (state, flash, quit, command, pass, ...) and any extension's `helpers`.
  class Extension
    # The builder classes `dsl` can add keywords to.
    TARGETS = {
      dashboard: -> { DSL::Dashboard::Builder },
      row: -> { DSL::Dashboard::RowBuilder },
      panel: -> { DSL::Dashboard::PanelBuilder },
      resource: -> { DSL::Resource::Builder }
    }.freeze

    Hook = Data.define(:extension, :matcher, :priority, :order, :block) do
      def match?(message) = matcher.nil? || matcher === message # rubocop:disable Style/CaseEquality
    end

    attr_reader :name, :modules, :hooks

    def initialize(name)
      @name = name.to_sym
      @modules = [] # [target class, module] pairs, for remove
      @hooks = Hash.new { |h, k| h[k] = [] }
    end

    # Adds the methods defined in the block as keywords on a DSL builder (:dashboard, :row,
    # :panel, :resource). Inside them, `declare(key, value)` records on the dashboard/resource
    # and `item(value)` adds a panel item. A keyword that already exists is an error.
    def dsl(target, &body)
      builder = TARGETS.fetch(target) { raise Error, "unknown DSL target #{target.inspect}" }.call
      add_module(builder, Module.new(&body))
    end

    # Methods available inside every hook and every user block (a Context).
    def helpers(&body) = add_module(Context, Module.new(&body))

    # Runs in App.new, before any frame (snapshots included): seed state here. Commands are ignored.
    def setup(&block) = hook(:setup, nil, block)

    # Runs once in App#init. Enqueue startup commands with `command(...)` (or return one).
    def init(&block) = hook(:init, nil, block)

    # Runs after init and after every update, on the same Context (its commands go out with that
    # update's): e.g. re-send the window title when the value it shows has changed.
    def after_update(&block) = hook(:after_update, nil, block)

    # Handles messages matching `matcher` (anything with ===: a class, a proc, a regexp...).
    # A matching handler consumes the message unless it calls `pass`. Higher priority runs first:
    # 100 = an open modal capturing keys, 50 and up = before the focused component (which comes
    # next), 0 = ordinary bindings, -100 = fallbacks. Core keys (tab, q, the table keys) run after
    # every handler; ctrl+c and the core search/confirm prompts run before them. See docs/dsl.md.
    def on(matcher, priority: 0, &block) = hook(:on, matcher, block, priority:)

    # Sees every matching message before any `on` handler; never consumes it.
    def observe(matcher = nil, &block) = hook(:observe, matcher, block)

    # Draws panel items of class `klass`. The block gets the item and returns a String (ANSI
    # allowed, lines split on "\n"); `width`, `height` and `panel` give the space it has. The panel
    # gives it as many lines as the string has (at most `height`).
    def panel_item(klass, &block) = hook(:panel_item, klass, block)

    # Hosts a Bubbletea-style model for each panel item of class `klass`; the block builds it from
    # the item. See R2UI::Component for what the app does with it. `focusable: true` routes keys
    # to it while its panel has focus.
    def component(klass, focusable: false, &build)
      raise ArgumentError, "component needs a build block" unless build

      hook(:component, klass, Component::Spec.new(matcher: klass, options: { focusable: }, build:))
    end

    # Extra status-bar hints: return [[key, label], ...] or nil.
    def hints(&block) = hook(:hints, nil, block)

    # Text for the left of the status bar when the core shows nothing (no prompt or flash).
    def status(&block) = hook(:status, nil, block)

    # Options for Bubbletea::Runner (alt_screen:, mouse_cell_motion:, bracketed_paste:, ...).
    # Return a Hash; later extensions win on the same key.
    def program_options(&block) = hook(:program_options, nil, block)

    # Replaces the whole view (no panels, no status bar) when it returns a String; nil leaves the
    # dashboard. `width` and `height` are the frame size. The first non-nil one wins.
    def view_override(&block) = hook(:view_override, nil, block)

    # Changes the size the app draws at: gets [width, height], returns [width, height].
    def frame_size(&block) = hook(:frame_size, nil, block)

    # Canvas styles: return { style_name => "SGR params" } to add or override (see Canvas::STYLES).
    def styles(&block) = hook(:styles, nil, block)

    # Empties its modules (they stay included, with no methods) and drops its hooks.
    def remove!
      @modules.each do |_target, mod|
        (mod.instance_methods(false) + mod.private_instance_methods(false)).each do |m|
          mod.send(:remove_method, m)
        end
      end
      @hooks.clear
    end

    private

    def hook(kind, matcher, block, priority: 0)
      raise ArgumentError, "#{kind} needs a block" unless block

      @hooks[kind] << Hook.new(extension: name, matcher:, priority:, order: Extensions.next_order, block:)
    end

    def add_module(target, mod)
      defined = mod.instance_methods(false) + mod.private_instance_methods(false)
      taken = defined.select do |m|
        target.method_defined?(m) || target.private_method_defined?(m)
      end
      raise Error, "extension #{name}: #{target} already has #{taken.join(", ")}" if taken.any?

      target.include(mod)
      @modules << [target, mod]
      mod
    end
  end

  # The loaded extensions, in load order.
  module Extensions
    @all = {}
    @order = 0
    @lock = Mutex.new

    class << self
      def register(name, &block)
        name = name.to_sym
        raise Error, "extension #{name} is already registered" if @all.key?(name)

        extension = Extension.new(name)
        @all[name] = extension
        begin
          extension.instance_eval(&block) if block
        rescue StandardError
          remove(name)
          raise
        end
        extension
      end

      def [](name) = @all[name.to_sym]

      def names = @all.keys

      # Unregisters an extension and removes its keywords and helpers (for tests).
      def remove(name)
        @all.delete(name.to_sym)&.remove!
      end

      # Hooks of one kind across all extensions: highest priority first, then load order.
      def hooks(kind)
        @all.values.flat_map { |e| e.hooks.fetch(kind, []) }.sort_by { |h| [-h.priority, h.order] }
      end

      def next_order = @lock.synchronize { @order += 1 }

      # Loads every file in `dir` (default lib/r2ui/ext/), sorted by name.
      def load_all(dir = File.expand_path("ext", __dir__))
        Dir[File.join(dir, "*.rb")].sort.each { |file| require file }
      end
    end
  end

  def self.extension(name, &) = Extensions.register(name, &)
end
