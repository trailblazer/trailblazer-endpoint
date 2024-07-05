require "bundler/gem_tasks"
require "rake/testtask"

task :default => [:test]

Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  # test.test_files = FileList['test/endpoint_test.rb', 'test/docs/*_test.rb', "test/adapter/*_test.rb", "test/config_test.rb"]
  test.test_files = FileList['test/controller_test.rb', 'test/matcher_test.rb', "test/runtime_test.rb"]
  test.verbose = true
end

# To run grape app's test, run below command
# $ appraisal rails-app rake test-rails-app
Rake::TestTask.new('test-rails-app') do |test|
  test.libs << 'test'
  test.test_files = FileList['test/rails-app/test/test_helper.rb', 'test/rails-app/test/**/*.rb']
  test.verbose = true
end

# To run grape app's test, run below command
# $ appraisal grape-app rake test-grape-app
Rake::TestTask.new('test-grape-app') do |test|
  test.libs << 'test'
  test.test_files = FileList['test/grape-app/test/test_helper.rb', 'test/grape-app/test/**/*.rb']
  test.verbose = true
end
