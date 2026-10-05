# frozen_string_literal: true

require "test_helper"

# R2UI::Motion on an injected clock: every test sets `@t` and evaluates.
class MotionTest < Minitest::Test
  def setup
    @t = 0.0
    @motion = R2UI::Motion.new(clock: -> { @t })
  end

  def at(time)
    @t = time
    yield
  end

  def test_tween_starts_at_its_target_then_glides_and_settles
    assert_in_delta 10.0, at(0.0) { @motion.tween(:cpu, 10, duration: 1.0, ease: :linear) }
    refute @motion.active?, "nothing moves until the target changes"

    assert_in_delta 10.0, at(0.0) { @motion.tween(:cpu, 20, duration: 1.0, ease: :linear) }
    assert @motion.active?
    assert_in_delta 15.0, at(0.5) { @motion.tween(:cpu, 20, duration: 1.0, ease: :linear) }
    assert @motion.active?
    assert_in_delta 20.0, at(1.0) { @motion.tween(:cpu, 20, duration: 1.0, ease: :linear) }
    refute @motion.active?, "settled"
  end

  def test_tween_retargets_from_where_it_is
    at(0.0) { @motion.tween(:x, 0, duration: 1.0, ease: :linear) }
    at(0.0) { @motion.tween(:x, 10, duration: 1.0, ease: :linear) }
    assert_in_delta 5.0, at(0.5) { @motion.tween(:x, 0, duration: 1.0, ease: :linear) }, 1e-9, "glides back from 5"
    assert_in_delta 2.5, at(1.0) { @motion.tween(:x, 0, duration: 1.0, ease: :linear) }
  end

  def test_tween_eases_and_passes_odd_targets_through
    at(0.0) { @motion.tween(:x, 0, duration: 1.0) }
    at(0.0) { @motion.tween(:x, 100, duration: 1.0) }
    assert_in_delta 87.5, at(0.5) { @motion.tween(:x, 100, duration: 1.0) }, 1e-9, "out_cubic is fast early"
    assert_equal "n/a", @motion.tween(:y, "n/a")
    assert_nil @motion.tween(:x, nil)
    assert_in_delta 7.0, @motion.tween(:x, 7), 1e-9, "nil forgot it, so the next target is immediate"
  end

  def test_pulse_fires_on_the_rising_edge_and_decays
    assert_in_delta 0.0, at(0.0) { @motion.pulse(:hit, false, duration: 1.0) }
    assert_in_delta 1.0, at(1.0) { @motion.pulse(:hit, true, duration: 1.0) }
    assert @motion.active?
    assert_in_delta 0.125, at(1.5) { @motion.pulse(:hit, true, duration: 1.0) }, 1e-9, "still true: no new pulse"
    assert_in_delta 0.0, at(2.0) { @motion.pulse(:hit, true, duration: 1.0) }
    refute @motion.active?
    at(2.5) { @motion.pulse(:hit, false, duration: 1.0) }
    assert_in_delta 1.0, at(3.0) { @motion.pulse(:hit, true, duration: 1.0) }, 1e-9, "fires again after going false"
  end

  def test_age_counts_since_the_value_changed
    assert_in_delta 0.0, at(0.0) { @motion.age(:state, :running) }
    assert_in_delta 2.0, at(2.0) { @motion.age(:state, :running) }
    assert_in_delta 0.0, at(3.0) { @motion.age(:state, :idle) }
    assert_in_delta 1.5, at(4.5) { @motion.age(:state, :idle) }
    refute @motion.active?, "ages alone don't animate"
  end

  def test_active_has_a_grace_period_when_nothing_evaluates_again
    at(0.0) { @motion.tween(:x, 0, duration: 0.4) }
    at(0.0) { @motion.tween(:x, 1, duration: 0.4) }
    at(0.1) { @motion.tween(:x, 1, duration: 0.4) }
    @t = 1.0
    assert @motion.active?, "within the tween's end plus GRACE"
    @t = 0.4 + R2UI::Motion::GRACE + 0.01
    refute @motion.active?, "the tween stopped being drawn"
  end

  def test_hold_keeps_it_active
    at(0.0) { @motion.hold(2.0) }
    @t = 1.0
    assert @motion.active?
    at(2.5) { @motion.hold(0) }
    refute @motion.active?
  end

  def test_disabled_motion_jumps_and_never_animates
    @motion.enabled = false
    at(0.0) { @motion.tween(:x, 0) }
    assert_in_delta 50.0, at(0.1) { @motion.tween(:x, 50) }
    assert_in_delta 0.0, @motion.pulse(:hit, true)
    @motion.hold(5)
    refute @motion.active?
  end

  def test_sweep_forgets_keys_not_evaluated_lately
    at(0.0) { @motion.tween(:old, 1) }
    at(25.0) { @motion.tween(:recent, 1) }
    @t = 40.0
    assert_equal 1, @motion.sweep!(older_than: 30)
    assert_in_delta 9.0, @motion.tween(:old, 9), 1e-9, "forgotten: a new key starts at its target"
    assert_in_delta 1.0, at(40.1) { @motion.tween(:recent, 9, ease: :linear, duration: 1.0) }, 1e-9, "kept"
  end

  def test_lerp_and_mix_hex
    assert_in_delta 7.5, R2UI::Motion.lerp(5, 10, 0.5)
    assert_equal "#808080", R2UI::Motion.mix_hex("#000000", "#ffffff", 0.5)
    assert_equal "#ffffff", R2UI::Motion.mix_hex("#000", "#fff", 2)
    assert_equal "#000000", R2UI::Motion.mix_hex("#000", "#fff", -1)
    assert_equal [255, 0, 16], R2UI::Motion.rgb("ff0010")
  end
end
