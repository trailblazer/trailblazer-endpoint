class ApplicationController::Api < ApplicationController
  extend Trailblazer::Endpoint::Controller
  include Trailblazer::Endpoint::Controller::InstanceMethods
  include Trailblazer::Endpoint::Controller::InstanceMethods::API

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

  endpoint protocol: Protocol, adapter: Trailblazer::Endpoint::Adapter::API do
    {Output(:not_found) => Track(:not_found)}
  end
end


# header 'Authorization', "Bearer #{result['jwt_token']}" if result['jwt_token']
