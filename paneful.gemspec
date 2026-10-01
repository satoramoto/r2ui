# frozen_string_literal: true

require_relative "lib/paneful/version"

Gem::Specification.new do |spec|
  spec.name = "paneful"
  spec.version = Paneful::VERSION
  spec.authors = ["Ryan Gavin"]
  spec.email = ["ryan.michael.gavin@gmail.com"]

  spec.summary = "ActiveAdmin-style DSL for terminal dashboards"
  spec.description = "Declare resources, scopes, groupings, columns and actions; " \
                     "Paneful draws the tables, charts and key bindings in your terminal."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir["lib/**/*.rb", "exe/*", "README.md", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = ["paneful"]
  spec.require_paths = ["lib"]
end
