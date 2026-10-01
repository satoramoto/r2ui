# frozen_string_literal: true

require "minitest/autorun"
require "paneful"

module Fixtures
  Proc = Data.define(:pid, :ppid, :name, :cwd, :cpu, :rss)

  ROWS = [
    Proc.new(pid: 1, ppid: 0, name: "launchd", cwd: "/", cpu: 0.5, rss: 10 * 1024**2),
    Proc.new(pid: 10, ppid: 1, name: "claude", cwd: "/src/a", cpu: 20.0, rss: 400 * 1024**2),
    Proc.new(pid: 11, ppid: 10, name: "zsh", cwd: "/src/a", cpu: 1.0, rss: 4 * 1024**2),
    Proc.new(pid: 12, ppid: 11, name: "cargo", cwd: "/src/a", cpu: 300.0, rss: 2 * 1024**3),
    Proc.new(pid: 20, ppid: 1, name: "codex", cwd: "/src/b", cpu: 5.0, rss: 200 * 1024**2),
    Proc.new(pid: 21, ppid: 20, name: "node", cwd: "/src/b", cpu: 2.0, rss: 100 * 1024**2)
  ].freeze

  module_function

  def define_processes(rows = ROWS)
    Paneful.resource :process do
      source { rows }
      key :pid, parent: :ppid
      scope(:agents, default: true) { |p| p.pid >= 10 }
      scope :all
      group_by :name
      group_by :cwd, label: "Directory"
      group_by :parent, tree: true
      index do
        column :pid, format: :id
        column :name
        column :cwd, format: :short_path
        column :cpu, format: :percent, sparkline: true, sort: :desc
        column :rss, label: "Memory", format: :bytes
      end
      filter :name, :cwd
    end
  end
end
