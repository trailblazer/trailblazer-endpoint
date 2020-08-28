#:app-controller
class ApplicationController::Api < ApplicationController
  include Trailblazer::Endpoint::Controller.module(api: true)

  def self.options_for_block_options(ctx, controller:, **)
    response_block = ->(ctx, endpoint_ctx:, **) do
      controller.render json: endpoint_ctx[:representer], status: endpoint_ctx[:status]
    end

    {
      success_block:          response_block,
      failure_block:          response_block,
      protocol_failure_block: response_block
    }
  end

  directive :options_for_block_options, method(:options_for_block_options)
#:app-controller end

#:options_for_endpoint
  def self.options_for_endpoint(ctx, controller:, **)
    {
      request: controller.request,
      errors_representer_class: App::Api::V1::Representer::Errors,
      errors: Trailblazer::Endpoint::Adapter::API::Errors.new,
    }
  end

  directive :options_for_endpoint, method(:options_for_endpoint)
#:options_for_endpoint end

#:options_for_domain_ctx
  def self.options_for_domain_ctx(ctx, controller:, **) # TODO: move to ApplicationController
    {
      params: controller.params,
    }
  end

  directive :options_for_domain_ctx,    method(:options_for_domain_ctx)
#:options_for_domain_ctx end

  #:protocol
  class Protocol < Trailblazer::Endpoint::Protocol
    step Auth::Operation::Policy, inherit: true, id: :policy, replace: :policy
    step Subprocess(Auth::Operation::Authenticate), inherit: true, id: :authenticate, replace: :authenticate
  end
  #:protocol end

  #:adapter
  module Adapter
    class Representable < Trailblazer::Endpoint::Adapter::API
      step :render # added before End.success
      step :render_errors, after: :_422_status, magnetic_to: :failure, Output(:success) => Track(:failure)
      step :render_errors, after: :protocol_failure, magnetic_to: :fail_fast, Output(:success) => Track(:fail_fast), id: :render_protocol_failure_errors

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
  #:adapter end

  endpoint protocol: Protocol, adapter: Adapter::RepresentableWithErrors do
    # {Output(:not_found) => Track(:not_found)}
    {}
  end
end


# header 'Authorization', "Bearer #{result['jwt_token']}" if result['jwt_token']
