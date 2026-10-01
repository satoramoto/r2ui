# frozen_string_literal: true

# Pure-Ruby Bubbletea: a drop-in for the bubbletea gem (0.1.4). The Ruby layer (messages, commands,
# model, runner) is upstream's, copied unchanged; native.rb replaces the Go extension
# (Bubbletea::Program and the module functions) with pure Ruby. Never loads the real gem.

require_relative "bubbletea/version"
require_relative "bubbletea/native"
require_relative "bubbletea/messages"
require_relative "bubbletea/commands"
require_relative "bubbletea/model"
require_relative "bubbletea/runner"

module Bubbletea
  class Error < StandardError; end
end
