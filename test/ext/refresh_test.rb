# frozen_string_literal: true

require "test_helper"

# s19-refresh: `refresh` / `refresh(:name)` fetch a resource now, in a background command, instead
# of waiting for its interval.
class RefreshTest < Minitest::Test
  Item = Data.define(:id, :label)

  def setup
    R2UI.reset!
    @fetches = Hash.new(0)
    @data = { jobs: [Item.new(1, "alpha")], hosts: [Item.new(1, "web-1")] }
    define_resource(:jobs)
    define_resource(:hosts)
    R2UI.dashboard do
      # The trigger: a timer whose block asks for the refresh named in state[:target].
      every 1 do
        state[:target] == :focused ? refresh : refresh(state[:target])
      end

      row do
        panel(:jobs) { table }
        panel(:hosts) { table }
      end
    end
    @app = R2UI::App.new(R2UI.registry)
    @app.init
    wait_for_first_fetches
    @fetches_after_start = @fetches.dup
  end

  def teardown = @app&.stop

  # A resource whose rows come from @data and whose interval is far too long to matter.
  def define_resource(name)
    fetches = @fetches
    data = @data
    R2UI.resource name do
      source do
        fetches[name] += 1
        data[name]
      end
      key :id
      refresh every: 3600
      index { column :label }
    end
  end

  def wait_for_first_fetches
    deadline = Time.now + 5
    sleep 0.01 until @app.feeds.values.all? { |f| f.version.positive? } || Time.now > deadline
  end

  def text = @app.frame(60, 10).plain_lines.join("\n")

  # Fires the timer and returns the commands its block enqueued.
  def trigger(target)
    @app.state[:target] = target
    _, init = @app.init
    tick = (init.is_a?(Bubbletea::BatchCommand) ? init.commands : [init]).grep(Bubbletea::TickCommand).first
    _, out = @app.update(tick.callback.call)
    out.is_a?(Bubbletea::BatchCommand) ? out.commands : [out].compact
  end

  # Runs a Proc command the way the runner does and delivers its message, if any.
  def run_command(command)
    result = Thread.new { command.call }.value
    @app.update(result) if result.is_a?(Bubbletea::Message)
  end

  def refresh_commands(target) = trigger(target).grep(Proc)

  def test_refresh_returns_a_background_command_and_fetches_nothing_on_the_update_thread
    commands = refresh_commands(:jobs)

    refute_empty commands
    assert_equal @fetches_after_start, @fetches, "the fetch waits for the runner"
  end

  def test_running_the_command_fetches_now_and_the_next_frame_shows_new_rows
    assert_match(/alpha/, text)
    @data[:jobs] = [Item.new(1, "alpha"), Item.new(2, "bravo")]
    refute_match(/bravo/, text, "the long interval hasn't brought them in")

    refresh_commands(:jobs).each { |c| run_command(c) }

    assert_equal @fetches_after_start[:jobs] + 1, @fetches[:jobs]
    assert_match(/bravo/, text)
  end

  def test_refresh_with_a_name_leaves_other_resources_alone
    @data[:jobs] = [Item.new(1, "alpha-2")]
    @data[:hosts] = [Item.new(1, "web-2")]

    refresh_commands(:hosts).each { |c| run_command(c) }

    assert_equal @fetches_after_start[:jobs], @fetches[:jobs]
    assert_match(/web-2/, text)
    refute_match(/alpha-2/, text)
  end

  def test_refresh_without_a_name_fetches_the_focused_panels_resource
    @app.focus = @app.dashboard.panels.last
    @data[:hosts] = [Item.new(1, "web-3")]

    refresh_commands(:focused).each { |c| run_command(c) }

    assert_equal @fetches_after_start[:hosts] + 1, @fetches[:hosts]
    assert_equal @fetches_after_start[:jobs], @fetches[:jobs]
    assert_match(/web-3/, text)
  end

  def test_refresh_of_an_unknown_resource_raises
    error = assert_raises(StandardError) { trigger(:nope) }

    assert_match(/nope/, error.message)
  end
end
