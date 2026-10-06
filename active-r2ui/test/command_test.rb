# frozen_string_literal: true

require "test_helper"
require "stringio"
require "open3"
require "rbconfig"
require "rails/command"

module ActiveR2UI
  class CommandTest < TestCase
    def setup
      super
      seed_orders
    end

    def test_rails_tui_snapshot_prints_the_model_list
      out = capture { Rails::Command.invoke("tui", ["--snapshot", "--width", "100", "--height", "12"]) }
      assert_match(/Order\s+orders\s+orders\s+3/, out)
      assert_equal 12, out.lines.size
    end

    def test_rails_tui_snapshot_of_one_model_by_class_name
      out = capture { Rails::Command.invoke("tui", ["Order", "--snapshot"]) }
      assert_match(/Customer/, out)
      assert_match(/99\.99/, out)
    end

    def test_app_tui_files_customise_models
      File.write(File.join(ROOT, "app", "tui", "orders.rb"), <<~RUBY)
        ActiveR2UI.register Order do
          index { column :status }
        end
      RUBY
      out = capture { Rails::Command.invoke("tui", ["orders", "--snapshot"]) }
      assert_match(/Status/, out)
      refute_match(/Total/, out)
    ensure
      File.delete(File.join(ROOT, "app", "tui", "orders.rb"))
    end

    # Without the Railtie, eager loading would expect app/tui/orders.rb to define `Orders`.
    # Runs in a fresh process: Zeitwerk eager-loads only once, so an earlier boot in this process
    # would make an in-process eager_load! a no-op whatever the Railtie does.
    def test_eager_loading_skips_app_tui
      script = <<~RUBY
        require "test_helper"
        File.write(File.join(ROOT, "app", "tui", "orders.rb"), "ActiveR2UI.register(Order) { limit 1 }\\n")
        begin
          Rails.autoloaders.main.reload # Zeitwerk lists app/tui at setup, before orders.rb existed
          Rails.application.eager_load!
          puts "registered=\#{ActiveR2UI.registered?(Order)}"
        rescue Exception => e
          puts "error=\#{e.class}: \#{e.message}"
        end
      RUBY
      dir = File.expand_path("..", __dir__)
      out, status = Open3.capture2e(RbConfig.ruby, "-I#{dir}/test", "-I#{dir}/lib", "-e", script, chdir: dir)
      assert status.success?, out
      assert_includes out, "registered=false"
    end

    def test_production_is_read_only_unless_writes_are_allowed
      ActiveR2UI.install!
      Command.new(screen: "orders", snapshot: true, production: true, out: StringIO.new).run
      assert ActiveR2UI.read_only?
      Command.new(screen: "orders", snapshot: true, production: true, allow_writes: true, out: StringIO.new).run
      refute ActiveR2UI.read_only?
    end

    def test_resolve_accepts_common_spellings
      ActiveR2UI.install!
      %w[orders Order order].each { |text| assert_equal :orders, Command.resolve(text) }
      error = assert_raises(Error) { Command.resolve("widgets") }
      assert_match(/customers, events, orders/, error.message)
    end

    private

    def capture
      original = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original
    end
  end
end
