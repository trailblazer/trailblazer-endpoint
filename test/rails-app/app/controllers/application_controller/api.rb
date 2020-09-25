#:app-controller
#:app-include
class ApplicationController::Api < ApplicationController
  include Trailblazer::Endpoint::Controller.module(api: true, application_controller: true)
#:app-include end

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

      Trailblazer::Endpoint::Adapter::API.insert_error_handler_steps!(self)
      include Trailblazer::Endpoint::Adapter::API::Errors::Handlers # handler methods to set an error message.
    end # Representable
  end
  #:adapter end

puts Trailblazer::Developer.render(Adapter::Representable)

  #:endpoint
  # app/controllers/application_controller/api.rb
  endpoint protocol: Protocol, adapter: Adapter::Representable do
    # {Output(:not_found) => Track(:not_found)}
    {}
  end
  #:endpoint end
end


# header 'Authorization', "Bearer #{result['jwt_token']}" if result['jwt_token']


# ΓΞΞ Protocol ΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞ˥
# | (Start)--->[Authenticate]-->[Policy]-->[Show]----------->((success))  |
# |                 |            |          | L------------->((failure))  |
# |                 |            |          L------------->((not_found))  |
# |                 |            L------------------->((not_authorized))  |
# |                 L----------------------------->((not_authenticated))  |
# |                                                     ((invalid_data))  |
# LΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞ˩
#--˥˩   ˪

# ΓΞΞ Adapter::Representable ΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞ˥
# |                                                                                                                                                                                                |
# | (Start)---> ΓΞΞ Protocol ΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞ˥                                                                                                          |
#               | (Start)--->[Authenticate]-->[Policy]-->[Show]----------->((success))  |--->[_200_status]--->[render]---------------------------------------------------------------->((success)) |
#               |                 |            |          | L------------->((failure))  |-˥                                                                                                        |
#               |                 |            |          L------------->((not_found))  |-|------------------------------->[_404_status]-----------v                                               |
#               |                 |            L------------------->((not_authorized))  |-|->[handle_not_authorized]------>[_403_status]--->[protocol_failure]--->[render_errors]--->((fail_fast)) |
#               |                 L----------------------------->((not_authenticated))  |-|->[handle_not_authenticated]--->[_401_status]-----------^                                               |
#               |                                                     ((invalid_data))  |-┴->[handle_invalid_data]-------->[_422_status]--->[render_errors]--------------------------->((failure)) |
#               LΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞ˩                                                                                                          |
# LΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞΞ˩
