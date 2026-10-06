# frozen_string_literal: true

require "test_helper"

module ActiveR2UI
  class BrowserTest < TestCase
    def setup
      super
      seed_orders
      ActiveR2UI.install!
    end

    def test_model_list_shows_models_tables_and_counts
      text = frame(Browser.new)
      assert_match(/Customer\s+customers\s+customers\s+1/, text)
      assert_match(/Order\s+orders\s+orders\s+3/, text)
      assert_match(/enter open/, text)
    end

    def test_enter_opens_the_selected_model_and_esc_goes_back
      browser = Browser.new
      frame(browser)
      browser.press(:down, :down) # Customer, Event, Order
      browser.press(:enter)
      assert_equal :orders, browser.current.dashboard.name
      text = frame(browser)
      assert_match(/Total/, text)
      assert_match(/esc models/, text)
      browser.press(:escape)
      assert_same browser.list, browser.current
      assert_equal 2, browser.list.panel_state(browser.list.focus).selected
    end

    def test_esc_on_the_list_and_keys_outside_a_browser_do_nothing
      browser = Browser.new
      frame(browser)
      browser.press(:escape)
      assert_same browser.list, browser.current

      plain = R2UI::App.new(R2UI.registry, ModelList::NAME)
      frame(plain)
      plain.press(:enter)
      assert_empty plain.store(:active_r2ui)
    end
  end
end
