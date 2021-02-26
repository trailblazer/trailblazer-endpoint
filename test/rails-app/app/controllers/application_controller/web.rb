#:app-include
#:options
#:protocol
#:generic
class ApplicationController::Web < ApplicationController
#~pskip
#~gskip
  include Trailblazer::Endpoint::Controller.module(dsl: true, application_controller: true)
#:app-include end

  def self.options_for_endpoint(ctx, controller:, **)
    {
      session: controller.session,
    }
  end

  directive :options_for_endpoint, method(:options_for_endpoint)
#:options end

  # directive :options_for_flow_options, method(:options_for_flow_options)
  # directive :options_for_block_options, method(:options_for_block_options)
#~pskip end
  class Protocol < Trailblazer::Endpoint::Protocol
    # provide method for {step :authenticate}
    def authenticate(ctx, session:, **)
      ctx[:current_user] = User.find_by(id: session[:user_id])
    end

    # provide method for {step :policy}
    def policy(ctx, domain_ctx:, **)
      Policy.(domain_ctx)
    end

    Trailblazer::Endpoint::Protocol::Controller.insert_copy_to_domain_ctx!(self, {:current_user => :current_user})
    Trailblazer::Endpoint::Protocol::Controller.insert_copy_from_domain_ctx!(self, {:model => :process_model})
  end
#:protocol end
  Policy = ->(domain_ctx) { domain_ctx[:params][:policy] == "false" ? false : true }
#~gskip end
  endpoint protocol: Protocol, adapter: Trailblazer::Endpoint::Adapter::Web
end
#:generic end

# do
#   {Output(:not_found) => Track(:not_found)}
# end
