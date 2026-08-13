# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  # rubocop optional until bundle install
end

desc "Run benchmarks"
task :benchmark do
  ruby "benchmark/run.rb"
end

desc "Run fixture evaluation harness"
task :eval do
  ruby "benchmark/eval_harness.rb"
end

desc "Open HeapScope console"
task :console do
  exec "ruby", "bin/console"
end

desc "Print diagnostic code catalog"
task :codes do
  require_relative "lib/heapscope"
  puts HeapScope::Catalog.to_text
end

namespace :docs do
  desc "Generate / print diagnostic code catalog for docs"
  task :codes do
    require_relative "lib/heapscope"
    puts HeapScope::Catalog.to_text
  end
end

task default: :test
