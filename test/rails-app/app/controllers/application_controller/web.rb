class ApplicationController::Web < ApplicationController
  extend Trailblazer::Endpoint::Controller
  include Trailblazer::Endpoint::Controller::InstanceMethods::DSL
  include Trailblazer::Endpoint::Controller::Rails
  extend Trailblazer::Endpoint::Controller::Rails::DefaultBlocks
  extend Trailblazer::Endpoint::Controller::Rails::DefaultParams
  include Trailblazer::Endpoint::Controller::Rails::Process

  # directive :options_for_endpoint, method(:options_for_endpoint), method(:request_options)
  # directive :options_for_flow_options, method(:options_for_flow_options)
  # directive :options_for_block_options, method(:options_for_block_options)

  Protocol = Class.new(Trailblazer::Endpoint::Protocol) do
    # no {:seq} dependency
    def authenticate(ctx, domain_ctx:, **)
      # puts domain_ctx[:params].inspect

puts "TODO: should we always inject params into the endpoint_ctx?"
      domain_ctx[:params][:authenticate] == "false" ? false : true
    end

    def policy(ctx, domain_ctx:, **)
      domain_ctx[:params][:policy] == "false" ? false : true
    end
  end

  endpoint protocol: Protocol, adapter: Trailblazer::Endpoint::Adapter::Web do
    {Output(:not_found) => Track(:not_found)}
  end
end
