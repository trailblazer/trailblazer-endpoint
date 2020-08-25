class ApplicationController::Api < ApplicationController
  extend Trailblazer::Endpoint::Controller
  include Trailblazer::Endpoint::Controller::InstanceMethods
  include Trailblazer::Endpoint::Controller::InstanceMethods::API

  # directive :options_for_endpoint, method(:options_for_endpoint), method(:request_options)
  # directive :options_for_flow_options, method(:options_for_flow_options)
  def self.options_for_block_options(ctx, controller:, **)
    {
      success_block: success_block = ->(ctx, endpoint_ctx:, **) { controller.render json: endpoint_ctx[:representer], status: endpoint_ctx[:status] },
      failure_block: success_block,
      protocol_failure_block: success_block
    }
  end

  def self.options_for_endpoint(ctx, controller:, **)
    {
      request: controller.request,
    }
  end

  def self.options_for_domain_ctx(ctx, controller:, **) # TODO: move to ApplicationController
    {
      params: controller.params,
    }
  end

  directive :options_for_block_options, method(:options_for_block_options)
  directive :options_for_endpoint, method(:options_for_endpoint)
  directive :options_for_domain_ctx,    method(:options_for_domain_ctx)

  Protocol = Class.new(Trailblazer::Endpoint::Protocol) do
    step Auth::Operation::Authenticate, inherit: true, id: :authenticate, replace: :authenticate

    def policy(ctx, domain_ctx:, **)
      domain_ctx[:params][:policy] == "false" ? false : true
    end
  end

  module Adapter
    class Representable < Trailblazer::Endpoint::Adapter::API
      step :render # added before End.success

      def render(ctx, domain_ctx:, representer_class:, **) # this is what usually happens in your {Responder}.
        ctx[:representer] = representer_class.new(domain_ctx[:model] || raise("no model found!"))
      end
    end

  end

  endpoint protocol: Protocol, adapter: Adapter::Representable do
    # {Output(:not_found) => Track(:not_found)}
    {}
  end
end


# header 'Authorization', "Bearer #{result['jwt_token']}" if result['jwt_token']
