# frozen_string_literal: true

# What Claude and Codex runs cost this Mac.
#   exe/paneful examples/agents.rb

require_relative "agents/probe"

Paneful.resource :process do
  source { AgentProbe.processes }
  refresh every: 2
  key :pid, parent: :ppid

  scope :agents, default: true, &:agent
  scope :all

  group_by :agent, label: "Session"
  group_by :cwd, label: "Directory"
  group_by :name
  group_by :parent, tree: true

  index do
    column :pid, format: :id
    column :name
    column :agent, label: "Session"
    column :cwd, label: "Directory", format: :short_path
    column :cpu, label: "CPU", format: :percent, sparkline: true, sort: :desc
    column :rss, label: "Memory", format: :bytes
  end

  filter :name, :cwd, :command

  action :terminate, key: "K", confirm: true do |process|
    Process.kill(:TERM, process.pid)
  end
end

Paneful.resource :memory do
  source { AgentProbe.memory }
  refresh every: 1

  attribute :total, format: :bytes
  attribute :used, format: :bytes
  attribute :app, label: "App", format: :bytes
  attribute :wired, format: :bytes
  attribute :compressed, format: :bytes
  attribute :compression_ratio, label: "Compression", format: :ratio
  attribute :cached, label: "Cached files", format: :bytes
  attribute :swap_used, label: "Swap used", format: :bytes
  attribute :swapouts_per_sec, label: "Swapping out", format: :bytes_per_sec
  attribute :compressions_per_sec, label: "Compressing", format: :bytes_per_sec
  attribute :pressure, label: "Memory pressure", format: :percent
end

Paneful.dashboard do
  title "Agents"

  row height: 15 do
    panel :memory, span: 1 do
      gauge :used, of: :total
      stat :app, :wired, :compressed, :compression_ratio, :cached, :swap_used, :swapouts_per_sec, :compressions_per_sec
      sparkline :pressure, height: 2
    end

    panel :sessions, resource: :process, span: 2, title: "Agent sessions" do
      table scope: :agents, group_by: :agent
    end
  end

  row { panel :process }
end
