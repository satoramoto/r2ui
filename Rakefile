# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

desc "Per-frame cost of the bench dashboards by stage, YJIT off and on, vs bench/results/baseline.json"
task :bench do
  ruby "bench/run.rb"
end

namespace :bench do
  desc "Run the bench and save it as bench/results/baseline.json"
  task :baseline do
    ruby "bench/run.rb --save-baseline"
  end

  desc "Profile the steady and animating frames (stackprof CPU and allocations, vernier flame graph)"
  task :profile do
    ruby "bench/profile.rb"
  end
end
