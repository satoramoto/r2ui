# frozen_string_literal: true

require "test_helper"
require_relative "compat/bubbletea/pty_helper"

# R2UI.run on a real pty: the app runs on r2ui's Bubbletea engine (alt screen, keys, timers) and
# restores the terminal when it quits.
class EngineTest < Minitest::Test
  APP = <<~RUBY
    require "r2ui"

    Fruit = Struct.new(:name, :count)
    R2UI.resource :fruit do
      source { [Fruit.new("apple", 3), Fruit.new("banana", 5)] }
      column :name
      column :count, format: :integer
      filter :name
    end

    R2UI.dashboard do
      every(0.05) { state[:ticks] = state[:ticks].to_i + 1 }
      row { panel :fruit }
      row(height: 3) { panel(:clock, resource: nil) { view { state[:ticks].to_i >= 3 ? "ticking" : "waiting" } } }
    end

    R2UI.run
  RUBY

  def test_runs_on_the_engine_and_restores_the_terminal
    run = PtyHelper.run(APP, load_path: [PtyHelper::LIB], width: 60, height: 16) do |driver|
      driver.wait_for("banana")
      driver.wait_for("ticking")
      driver.type("/", "b", "a")
      driver.wait_for("/ba")
      driver.type("\r", "q")
    end

    assert run.status.success?, run.output.inspect
    assert run.tty_restored, "terminal left in raw mode"
    assert run.output.start_with?("\e[?25l\e[?1049h"), run.output[0, 40].inspect
    assert run.output.end_with?("\e[?1049l\e[?25h"), run.output[-40..].inspect
  end
end
