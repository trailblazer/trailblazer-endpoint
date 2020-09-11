class ApplicationController::Web < ApplicationController
  include Trailblazer::Endpoint::Controller.module(dsl: true, application_controller: true)

  def self.options_for_endpoint(ctx, controller:, **)
    {
      session: controller.session,
    }
  end

  directive :options_for_endpoint, method(:options_for_endpoint)
  # directive :options_for_flow_options, method(:options_for_flow_options)
  # directive :options_for_block_options, method(:options_for_block_options)

  Protocol = Class.new(Trailblazer::Endpoint::Protocol) do
    def authenticate(ctx, session:, **)
      # puts domain_ctx[:params].inspect
      puts "@@@@@ #{session.inspect}"

      ctx[:current_user] = User.find_by(id: session[:user_id])
    end

    def policy(ctx, domain_ctx:, **)
      domain_ctx[:params][:policy] == "false" ? false : true
    end
  end

  endpoint protocol: Protocol, adapter: Trailblazer::Endpoint::Adapter::Web,
    domain_ctx_filter: ApplicationController.current_user_in_domain_ctx do
      {Output(:not_found) => Track(:not_found)}
    end
end
