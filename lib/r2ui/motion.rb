# frozen_string_literal: true

module R2UI
  # Time-based animation state for one app: tweens (a number glides to its new value), pulses (a
  # flash that fades after an event) and ages (how long a value has been what it is). Everything is
  # keyed by whatever the caller passes (a pid, [:row, id], ...), evaluated while drawing a frame.
  #
  # `active?` tells the app whether anything was still moving at the last evaluation, so it keeps
  # drawing frames only while something animates.
  class Motion
    EASES = {
      linear: ->(t) { t },
      out_cubic: ->(t) { 1 - ((1 - t)**3) },
      in_out_sine: ->(t) { -(Math.cos(Math::PI * t) - 1) / 2 },
      out_back: lambda do |t|
        c1 = 1.70158
        1 + ((c1 + 1) * ((t - 1)**3)) + (c1 * ((t - 1)**2))
      end
    }.freeze

    # How long `active?` may stay true after the last evaluation if nothing evaluates again (e.g. the
    # animated thing stopped being drawn).
    GRACE = 1.0

    attr_accessor :enabled, :clock

    def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @clock = clock
      @enabled = true
      @tweens = {} # key => [from, to, start, duration, ease]
      @pulses = {} # key => [fired, start, duration]
      @ages = {}   # key => [value, since]
      @seen = {}   # key => last evaluated at
      @busy_until = nil
      @evaluated_at = nil
    end

    def self.lerp(a, b, t) = a + ((b - a) * t)

    # "#rrggbb" between two "#rrggbb" colours (t in 0..1, plain RGB lerp).
    def self.mix_hex(from_hex, to_hex, t)
      t = t.to_f.clamp(0.0, 1.0)
      ar, ag, ab = rgb(from_hex)
      br, bg, bb = rgb(to_hex)
      format("#%02x%02x%02x", lerp(ar, br, t).round.clamp(0, 255), lerp(ag, bg, t).round.clamp(0, 255),
             lerp(ab, bb, t).round.clamp(0, 255))
    end

    RGB_CACHE_LIMIT = 4096
    @rgb_cache = {}

    # [r, g, b] (frozen) for "#rrggbb" or "#rgb". Memoized (bounded).
    def self.rgb(hex)
      cached = @rgb_cache[hex]
      return cached if cached

      @rgb_cache.clear if @rgb_cache.size >= RGB_CACHE_LIMIT
      @rgb_cache[hex] = parse_rgb(hex)
    end

    def self.parse_rgb(hex)
      h = hex.to_s.delete_prefix("#")
      h = h.chars.map { |c| c * 2 }.join if h.length == 3
      [h[0, 2], h[2, 2], h[4, 2]].map { |p| p.to_i(16) }.freeze
    end
    private_class_method :parse_rgb

    def now = @clock.call

    # The displayed value for `key`: glides from the displayed value to `target` whenever the target
    # changes. nil forgets the key; a non-numeric target is returned unchanged.
    def tween(key, target, duration: 0.4, ease: :out_cubic)
      if target.nil?
        forget(key)
        return nil
      end
      return target unless target.is_a?(Numeric)

      t = mark(key)
      state = @tweens[key]
      if state.nil? || !@enabled
        @tweens[key] = [target.to_f, target.to_f, t, duration, ease]
        return target.to_f
      end
      if target.to_f != state[1]
        from = tween_value(state, t)
        state = @tweens[key] = [from, target.to_f, t, duration, ease]
      end
      tween_value(state, t)
    end

    # 1.0 on the frame `fire` turns truthy, easing out to 0.0 over `duration`; 0.0 otherwise.
    def pulse(key, fire, duration: 1.0)
      t = mark(key)
      fired, start, = @pulses[key]
      start = t if fire && !fired
      @pulses[key] = [fire ? true : false, start, duration]
      return 0.0 unless @enabled && start

      progress = duration.positive? ? (t - start) / duration : 1.0
      return 0.0 if progress >= 1

      busy(start + duration)
      1.0 - EASES[:out_cubic].call(progress.clamp(0.0, 1.0))
    end

    # Seconds since `value` last changed for `key` (0.0 the first time it is seen).
    def age(key, value)
      t = mark(key)
      old, since = @ages[key]
      if since.nil? || old != value
        @ages[key] = [value, t]
        return 0.0
      end
      t - since
    end

    # Keeps `active?` true for `seconds` more (for marks drawn from `age` that are still fading).
    def hold(seconds)
      t = now
      @evaluated_at = t
      busy(t + seconds) if @enabled && seconds.positive?
    end

    # Whether a tween, pulse or hold was still in progress at the last evaluation.
    def active?
      return false unless @enabled && @busy_until && @evaluated_at

      @evaluated_at < @busy_until && now < @busy_until + GRACE
    end

    # Forgets keys not evaluated for `older_than` seconds.
    def sweep!(older_than: 30)
      cutoff = now - older_than
      stale = @seen.select { |_, at| at < cutoff }.keys
      stale.each { |key| forget(key) }
      stale.size
    end

    def forget(key)
      @tweens.delete(key)
      @pulses.delete(key)
      @ages.delete(key)
      @seen.delete(key)
    end

    private

    def mark(key)
      t = now
      @seen[key] = t
      @evaluated_at = t
      t
    end

    def busy(until_time)
      @busy_until = until_time if @busy_until.nil? || until_time > @busy_until
    end

    def tween_value(state, t)
      from, to, start, duration, ease = state
      progress = duration.positive? ? (t - start) / duration : 1.0
      return to if progress >= 1

      busy(start + duration)
      Motion.lerp(from, to, EASES.fetch(ease).call(progress.clamp(0.0, 1.0)))
    end
  end
end
