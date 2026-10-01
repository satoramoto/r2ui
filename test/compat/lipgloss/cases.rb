# frozen_string_literal: true

# Registry of lipgloss conformance cases. No lipgloss dependency: the recorder loads this next to the
# real gem, the conformance test loads it next to ours.
#
#   LipglossCases.define("style") do
#     add "style.bold", %q{Lipgloss::Style.new.bold(true).render("Hello")}
#   end
#
# Ids are "<area>.<name>" and unique. Each case is a Ruby snippet whose value is the result; it is
# evaluated in a fresh binding, so locals don't leak between cases. Results must be plain JSON values
# (String, Integer, Float, true, false, nil, Array, Hash with String keys).
module LipglossCases
  Case = Struct.new(:id, :area, :code)

  # Profile name => what the conformance test sets on our renderer. The recorder maps the same names to
  # terminal environments for the real gem (see record.rb).
  PROFILES = {
    "true_color" => { color_profile: :true_color, dark: true },
    "ansi256" => { color_profile: :ansi256, dark: true },
    "ansi" => { color_profile: :ansi, dark: true },
    "ascii" => { color_profile: :ascii, dark: true },
    "true_color_light" => { color_profile: :true_color, dark: false }
  }.freeze

  DIR = File.join(__dir__, "cases")
  GOLDENS = File.join(__dir__, "goldens")

  @cases = {}

  class Builder
    def initialize(area)
      @area = area
    end

    def add(id, code)
      LipglossCases.register(@area, id, code)
    end
  end

  class << self
    def define(area, &block)
      Builder.new(area).instance_eval(&block)
    end

    def register(area, id, code)
      raise ArgumentError, "case id #{id.inspect} must start with #{area}." unless id.start_with?("#{area}.")
      raise ArgumentError, "duplicate case id #{id.inspect}" if @cases.key?(id)

      @cases[id] = Case.new(id, area, code)
    end

    def areas
      Dir[File.join(DIR, "*.rb")].map { |path| File.basename(path, ".rb") }.sort
    end

    def load_areas(names = areas)
      names.each { |name| load File.join(DIR, "#{name}.rb") }
      self
    end

    def cases(area = nil)
      list = @cases.values
      area ? list.select { |c| c.area == area } : list
    end

    def [](id)
      @cases.fetch(id)
    end

    # Evaluates one case and returns its value, or {"error" => class name, "message" => message} when it
    # raises. Non-JSON values are reported as an error so a bad case can't record silently.
    def capture(code, name = "(case)")
      value = eval(code, fresh_binding, name) # rubocop:disable Security/Eval
      return value if json_value?(value)

      { "error" => "LipglossCases::NotJSON", "message" => "case returned #{value.class}" }
    rescue Exception => e # rubocop:disable Lint/RescueException
      raise if e.is_a?(Interrupt) || e.is_a?(SystemExit) || e.is_a?(NoMemoryError)

      { "error" => e.class.name, "message" => e.message.to_s }
    end

    def json_value?(value)
      case value
      when String then value.valid_encoding?
      when Integer, true, false, nil then true
      when Float then value.finite?
      when Array then value.all? { |v| json_value?(v) }
      when Hash then value.all? { |k, v| k.is_a?(String) && json_value?(v) }
      else false
      end
    end

    private

    def fresh_binding
      Object.new.instance_eval { binding }
    end
  end
end
