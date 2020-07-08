require "bundler/gem_tasks"
require "rake/testtask"

task :default => [:test]

Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.test_files = FileList['test/endpoint_test.rb', 'test/docs/*_test.rb', "test/adapter/*_test.rb"]
  test.verbose = true
end
