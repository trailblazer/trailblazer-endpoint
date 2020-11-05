appraise 'rails-app' do
  gem 'rails', '6.0.3.1'
  gem 'sqlite3', '~> 1.4'
  gem "trailblazer-operation", '>= 0.6.5'
end

appraise 'grape-app' do
  gem 'grape', '~> 1.5'
  gem "zeitwerk", "~> 2.4"
  gem "trailblazer-operation", '>= 0.6.5'
  gem "trailblazer-endpoint", path: "../../."

  gem "minitest-line", "~> 0.6"
  gem "rack-test", "1.1.0"
end
