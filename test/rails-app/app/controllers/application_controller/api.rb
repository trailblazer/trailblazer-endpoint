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
      errors_representer_class: App::Api::V1::Representer::Errors,
      errors: Trailblazer::Endpoint::Adapter::API::Errors.new,
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
    step Subprocess(Auth::Operation::Authenticate), inherit: true, id: :authenticate, replace: :authenticate

    def policy(ctx, domain_ctx:, **)
      domain_ctx[:params][:policy] == "false" ? false : true
    end
  end

  module Adapter
    class Representable < Trailblazer::Endpoint::Adapter::API
      step :render # added before End.success
      step :render_errors, after: :_422_status, magnetic_to: :failure, Output(:success) => Track(:failure)

      def render(ctx, domain_ctx:, representer_class:, **) # this is what usually happens in your {Responder}.
        ctx[:representer] = representer_class.new(domain_ctx[:model] || raise("no model found!"))
      end

      def render_errors(ctx, errors:, errors_representer_class:, **) # TODO: extract with {render}
        ctx[:representer] = errors_representer_class.new(errors)
      end
    end

    RepresentableWithErrors = Trailblazer::Endpoint::Adapter::API.insert_error_handler_steps(Representable)
    RepresentableWithErrors.include(Trailblazer::Endpoint::Adapter::API::Errors::Handlers)

  end


      # puts Trailblazer::Developer.render(Adapter::Representable)

  endpoint protocol: Protocol, adapter: Adapter::RepresentableWithErrors do
    # {Output(:not_found) => Track(:not_found)}
    {}
  end
end


# header 'Authorization', "Bearer #{result['jwt_token']}" if result['jwt_token']
