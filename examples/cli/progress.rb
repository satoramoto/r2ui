#!/usr/bin/env ruby
# frozen_string_literal: true

# Progress bars (c05-progress): a pretend download, a file copy and a scan of unknown size. Try:
#   ruby examples/cli/progress.rb
#   ruby examples/cli/progress.rb | cat
require_relative "../../lib/r2ui/cli"

R2UI.cli "fetcher" do
  summary "Pretend to download things"
  option :seconds, :float, default: 3.0, desc: "How long each bar takes"

  run do
    pause = options[:seconds] / 50

    progress(total: 48_000_000, title: "Downloading", unit: :bytes) do |bar|
      50.times { sleep pause; bar.advance(960_000) }
    end

    progress(total: 120, title: "Copying", unit: "files") do |bar|
      120.times { |i| sleep pause / 2.4; bar.current = i + 1 }
    end

    progress(title: "Scanning") do |bar|
      30.times { sleep pause * 50 / 30; bar.advance(rand(5..40)) }
    end
  end
end.start
