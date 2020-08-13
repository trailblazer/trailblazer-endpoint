require "trailblazer/endpoint/controller"

class ApplicationController < ActionController::Base
  extend Trailblazer::Endpoint::Controller
  include Trailblazer::Endpoint::Controller::Rails
  extend Trailblazer::Endpoint::Controller::Rails::DefaultBlocks
  extend Trailblazer::Endpoint::Controller::Rails::DefaultParams
  include Trailblazer::Endpoint::Controller::Rails::Process

  # directive :options_for_endpoint, method(:options_for_endpoint), method(:request_options)
  # directive :options_for_flow_options, method(:options_for_flow_options)
  # directive :options_for_block_options, method(:options_for_block_options)

  Protocol = Class.new(Trailblazer::Endpoint::Protocol) do
    # no {:seq} dependency
    def authenticate(ctx, authenticate: true, **)
      authenticate
    end

    def policy(ctx, policy: true, **)
      policy
    end
  end

  endpoint protocol: ApplicationController::Protocol, adapter: Trailblazer::Endpoint::Adapter::Web
end
