lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'trailblazer/endpoint/version'

Gem::Specification.new do |spec|
  spec.name          = "trailblazer-endpoint"
  spec.version       = Trailblazer::Endpoint::VERSION
  spec.authors       = ["Nick Sutterer"]
  spec.email         = ["apotonick@gmail.com"]
  spec.description   = %q{Endpoints handle authentication, policies, run your domain operation and prepare rendering.}
  spec.summary       = %q{Endpoints handle authentication, policies, run your domain operation and prepare rendering.}
  spec.homepage      = "https://trailblazer.to/2.1/docs/endpoint.html"
  spec.license       = "LGPL-3.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "trailblazer-activity-dsl-linear", ">= 1.2.0", "< 1.3.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "trailblazer-developer"
  spec.add_development_dependency "trailblazer-core-utils"
  spec.add_development_dependency "trailblazer-operation" # DISCUSS: we currently test if Operation creates Context properly with {endpoint}.
end
