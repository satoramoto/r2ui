# frozen_string_literal: true

# Replays the lipgloss goldens (recorded from the real gem by record.rb) against r2ui's pure-Ruby
# lipgloss. One test per case and color profile; the profile is set through
# R2UI::Compat::Gloss::Renderer.color_profile / .has_dark_background.

require "minitest/autorun"
require "json"
require "timeout"

lib = File.expand_path("../../../lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require_relative "cases"

module LipglossConformance
  LOAD_ERROR =
    begin
      require "r2ui/drop_in"
      require "lipgloss"
      nil
    rescue ScriptError, StandardError => e
      "#{e.class}: #{e.message}"
    end

  def self.renderer
    return nil unless defined?(R2UI::Compat::Gloss::Renderer)

    R2UI::Compat::Gloss::Renderer
  end

  module Assertions
    def setup
      super
      flunk "require \"lipgloss\" (r2ui drop-in) failed: #{LOAD_ERROR}" if LOAD_ERROR
      renderer = LipglossConformance.renderer
      flunk "R2UI::Compat::Gloss::Renderer is not defined" unless renderer
      %i[color_profile= has_dark_background=].each do |hook|
        flunk "R2UI::Compat::Gloss::Renderer.#{hook} is not defined" unless renderer.respond_to?(hook)
      end
    end

    def teardown
      renderer = LipglossConformance.renderer
      if renderer
        renderer.color_profile = nil if renderer.respond_to?(:color_profile=)
        renderer.has_dark_background = nil if renderer.respond_to?(:has_dark_background=)
      end
      super
    end

    def assert_golden(id, code, profile, expected)
      spec = LipglossCases::PROFILES.fetch(profile)
      LipglossConformance.renderer.color_profile = spec[:color_profile]
      LipglossConformance.renderer.has_dark_background = spec[:dark]
      actual = Timeout.timeout(10) { LipglossCases.capture(code, "case:#{id}") }
      return pass if actual == expected

      flunk <<~MSG
        #{id} [#{profile}] differs from the real gem
          code:     #{code}
          expected: #{expected.inspect}
          actual:   #{actual.inspect}
      MSG
    end
  end

  Dir[File.join(LipglossCases::GOLDENS, "*.json")].sort.each do |path|
    area = File.basename(path, ".json")
    klass = Class.new(Minitest::Test) { include Assertions }
    const_set("#{area.capitalize}Test", klass)

    JSON.parse(File.read(path)).each do |id, golden|
      results = golden.fetch("results")
      LipglossCases::PROFILES.each_key do |profile|
        expected = results.key?("*") ? results["*"] : results.fetch(profile)
        code = golden.fetch("code")
        klass.define_method("test_#{id} [#{profile}]") { assert_golden(id, code, profile, expected) }
      end
    end
  end
end
