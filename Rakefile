require "bundler/gem_tasks"
require "rake/testtask"

task :default => [:test]

Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.test_files = FileList['test/endpoint_test.rb', 'test/docs/endpoint_test.rb', "test/api_test.rb"]
  test.verbose = true
end
