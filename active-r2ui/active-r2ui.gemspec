# frozen_string_literal: true

require_relative "lib/active_r2ui/version"

Gem::Specification.new do |spec|
  spec.name = "active-r2ui"
  spec.version = ActiveR2UI::VERSION
  spec.authors = ["Ryan Gavin"]
  spec.email = ["ryan.michael.gavin@gmail.com"]

  spec.summary = "r2ui terminal dashboards for Rails apps: `bin/rails tui`"
  spec.description = "Registers every ActiveRecord model as an r2ui resource (columns, formats, search, " \
                     "named scopes, model-method actions) and adds `bin/rails tui` to browse them."
  spec.homepage = "https://github.com/satoramoto/r2ui/tree/main/active-r2ui"
  spec.license = "MIT"
  spec.metadata = {
    "source_code_uri" => "https://github.com/satoramoto/r2ui",
    "changelog_uri" => "https://github.com/satoramoto/r2ui/blob/main/CHANGELOG.md"
  }
  spec.required_ruby_version = ">= 3.3"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.1"
  spec.add_dependency "r2ui", ">= 0.2"
  spec.add_dependency "railties", ">= 7.1"
end
