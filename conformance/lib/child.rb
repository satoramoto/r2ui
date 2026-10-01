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

case_path = ARGV.fetch(0)
cols, rows = ENV.fetch("CONFORMANCE_SIZE").split("x").map { |n| Integer(n) }
$stdout.winsize = [rows, cols] if $stdout.tty?

out = ENV["CONFORMANCE_OUT"]
if out
  source = File.read(case_path).split(/^__END__\r?\n/, 2).first
  result = TOPLEVEL_BINDING.eval(source, case_path, 1)
  unless result.is_a?(String)
    warn "conformance: #{case_path} returned #{result.class}, expected a String"
    exit 2
  end
  File.binwrite(out, result)
else
  load case_path
end
