# frozen_string_literal: true

# Runs one conformance case inside the pty the harness spawned. The harness decides which gems
# load: recording runs this plainly (the real gems); checking adds `-I lib -r r2ui/drop_in`.
#
#   ruby [-I lib -r r2ui/drop_in] conformance/lib/child.rb <case.rb>
#
# CONFORMANCE_SIZE ("COLSxROWS") sets the terminal size before the case loads anything.
# CONFORMANCE_OUT, when set, marks a value case: the file's last expression must be a String,
# and it is written there byte for byte. Otherwise the case is a program and simply runs.

require "io/console"

# No top-level locals in this file: a value case is evaluated at the top level, where it would
# see (and could overwrite) them. Harness state lives in constants and methods.
CONFORMANCE_CASE = ARGV.fetch(0)
$stdout.winsize = ENV.fetch("CONFORMANCE_SIZE").split("x").map { |n| Integer(n) }.reverse if $stdout.tty?

# Under `check` (CONFORMANCE_FLAVOR=r2ui) the case must run on r2ui alone: if any file of the
# real bubbletea/lipgloss gems got loaded, the comparison proves nothing, so the case fails.
REAL_GEM_FILE = %r{/gems/(bubbletea|lipgloss)-[^/]+/}
def conformance_assert_r2ui_only!
  return unless ENV["CONFORMANCE_FLAVOR"] == "r2ui"

  leaked = $LOADED_FEATURES.grep(REAL_GEM_FILE)
  return if leaked.empty?

  warn "conformance: real upstream gem loaded under r2ui: #{leaked.first(3).join(', ')}"
  exit! LEAK_EXIT
end
LEAK_EXIT = 97 # the harness turns this exit status into a case error
if ENV["CONFORMANCE_FLAVOR"] == "r2ui"
  conformance_assert_r2ui_only! # drop_in itself must not pull them in
  # Check after every require so a long-running program case fails at once, not only at exit.
  Kernel.prepend(Module.new do
    private def require(*) = super.tap { conformance_assert_r2ui_only! }
  end)
  at_exit { conformance_assert_r2ui_only! }
end

# Evaluates a value case at the top level (self is main, `def` defines top-level methods) in a
# binding of its own, so its locals stay its own; this method's locals are invisible to it.
def conformance_value_case(path, out)
  source = File.read(path).split(/^__END__\r?\n/, 2).first
  result = TOPLEVEL_BINDING.dup.eval(source, path, 1)
  unless result.is_a?(String)
    warn "conformance: #{path} returned #{result.class}, expected a String"
    exit 2
  end
  conformance_assert_r2ui_only!
  File.binwrite(out, result)
end

if ENV["CONFORMANCE_OUT"]
  conformance_value_case(CONFORMANCE_CASE, ENV.fetch("CONFORMANCE_OUT"))
else
  load CONFORMANCE_CASE
end
