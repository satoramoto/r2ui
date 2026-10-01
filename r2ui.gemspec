# frozen_string_literal: true

require_relative "lib/r2ui/version"

Gem::Specification.new do |spec|
  spec.name = "r2ui"
  spec.version = R2UI::VERSION
  spec.authors = ["Ryan Gavin"]
  spec.email = ["ryan.michael.gavin@gmail.com"]

  spec.summary = "ActiveAdmin-style DSL for terminal dashboards"
  spec.description = "Declare resources, scopes, groupings, columns and actions; " \
                     "R2UI draws the tables, charts and key bindings in your terminal."
  spec.homepage = "https://github.com/satoramoto/r2ui"
  spec.license = "MIT"
  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md"
  }
  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir["lib/**/*.rb", "lib/**/LICENSE*", "exe/*", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.bindir = "exe"
  spec.executables = ["r2ui"]
  spec.require_paths = ["lib"]
end
