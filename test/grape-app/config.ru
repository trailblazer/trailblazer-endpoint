require "grape"
require "zeitwerk"

require "trailblazer/operation"
require "trailblazer/endpoint"

loader = Zeitwerk::Loader.new
loader.push_dir("#{__dir__}/app/api")
loader.push_dir("#{__dir__}/app/models")
loader.push_dir("#{__dir__}/app/concepts")
loader.setup

App::API.compile!
run App::API
