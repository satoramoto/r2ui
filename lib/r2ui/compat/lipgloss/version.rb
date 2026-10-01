# frozen_string_literal: true

module Lipgloss
  VERSION = "0.2.2"
end

module R2UI
  module Compat
    # Internals of the pure-Ruby lipgloss (see lib/r2ui/compat/lipgloss.rb).
    module Gloss
      # The Go lipgloss version the real gem wraps; returned by Lipgloss.upstream_version.
      UPSTREAM_VERSION = "v1.1.0"
    end
  end
end
