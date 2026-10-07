# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "logger"

# A minimal Rails app on a temporary sqlite file (a file, not :memory:, so feed threads and the
# main thread see the same data through different pool connections).
ROOT = Dir.mktmpdir("active-r2ui-test")
Minitest.after_run { FileUtils.remove_entry(ROOT) }
FileUtils.mkdir_p(File.join(ROOT, "app", "tui"))
ENV["DATABASE_URL"] = "sqlite3:#{File.join(ROOT, "test.sqlite3")}"
ENV["RAILS_ENV"] = "test"

require "rails"
require "active_record/railtie"
require "active_r2ui"

class TestApp < Rails::Application
  config.root = ROOT
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "test" * 16
  config.active_support.deprecation = :silence
end
Rails.application.initialize!

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :customers do |t|
    t.string :name
    t.string :email
    t.timestamps
  end
  create_table :orders do |t|
    t.references :customer
    t.string :status
    t.decimal :total, precision: 10, scale: 2
    t.boolean :paid, default: false
    t.text :notes
    t.json :payload
    t.date :due_on
    t.timestamps
  end
  create_table :tokens, id: :string do |t|
    t.timestamps
  end
  create_table :events, id: false do |t|
    t.string :kind
  end
end

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class Customer < ApplicationRecord
  has_many :orders
end

class Order < ApplicationRecord
  belongs_to :customer, optional: true
  scope :pending, -> { where(status: "pending") }

  def ship = update!(status: "shipped")
end

class RushOrder < Order; end # STI subclass: shares orders, not listed

class Event < ApplicationRecord; end # no primary key

class Token < ApplicationRecord; end # string primary key

class Ghost < ApplicationRecord; end # no table

module ActiveR2UI
  class TestCase < Minitest::Test
    def setup
      ActiveR2UI.reset!
      Order.delete_all
      Customer.delete_all
      Event.delete_all
      Token.delete_all
    end

    def seed_orders
      ada = Customer.create!(name: "Ada", email: "ada@example.com")
      Order.create!(customer: ada, status: "pending", total: 12.5, paid: false, notes: "leave\nat door",
                    payload: { a: 1 }, due_on: Date.today, created_at: Time.now - 180)
      Order.create!(customer: ada, status: "shipped", total: 99.99, paid: true, created_at: Time.now - 7200)
      Order.create!(status: "pending", total: 3, paid: true, created_at: Time.now - 30)
    end

    # Plain text of one frame of an App (or Browser) after fetching its feeds once.
    def frame(app, width: 140, height: 20)
      app = app.current if app.respond_to?(:current)
      app.feeds.each_value(&:refresh!)
      app.frame(width, height).plain_lines.join("\n")
    end
  end
end
