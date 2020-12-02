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
  end
#:protocol end
  Policy = ->(domain_ctx) { domain_ctx[:params][:policy] == "false" ? false : true }
#~gskip end
  endpoint protocol: Protocol, adapter: Trailblazer::Endpoint::Adapter::Web,
    domain_ctx_filter: ApplicationController.current_user_in_domain_ctx




  require "trailblazer/workflow"
  class SerializingProtocol < Protocol
    Trailblazer::Endpoint::Protocol::Controller.insert_deserialize_steps!(self, around_activity_id: :domain_activity)
    Trailblazer::Endpoint::Protocol::Controller.insert_serialize_steps!(self, around_activity_id: :domain_activity)

    pass Trailblazer::Endpoint::Protocol.method(:copy_process_model_to_domain_ctx), id: :copy_process_model_to_domain_ctx, before: :domain_activity
    pass :copy_resume_data_to_domain_ctx, before: :domain_activity

    def copy_process_model_to_domain_ctx(ctx, domain_ctx:, **)
      domain_ctx[:model]       = ctx[:process_model] if ctx.key?(:process_model)
    end

    # TODO: only in a suspend/resume protocol
    def copy_resume_data_to_domain_ctx(ctx, domain_ctx:, **)
      domain_ctx[:resume_data] = ctx[:resume_data] # FIXME: this should be done in endpoint/suspendresume
    end
  end

  class OnlyDeserializingProtocol < Protocol
    Trailblazer::Endpoint::Protocol::Controller.insert_deserialize_steps!(self, around_activity_id: :domain_activity)

    # pass Trailblazer::Endpoint::Protocol.method(:copy_process_model_to_domain_ctx), id: :copy_process_model_to_domain_ctx, before: :domain_activity
    pass :copy_resume_data_to_domain_ctx, before: :domain_activity

    # TODO: only in a suspend/resume protocol
    def copy_resume_data_to_domain_ctx(ctx, domain_ctx:, **)
      domain_ctx[:resume_data] = ctx[:resume_data] # FIXME: this should be done in endpoint/suspendresume
    end
  end

  class OnlySerializingProtocol < Protocol
    Trailblazer::Endpoint::Protocol::Controller.insert_serialize_steps!(self, around_activity_id: :domain_activity)

    pass Trailblazer::Endpoint::Protocol.method(:copy_process_model_to_domain_ctx), id: :copy_process_model_to_domain_ctx, before: :domain_activity
    pass :copy_resume_data_to_domain_ctx, before: :domain_activity

    def copy_process_model_to_domain_ctx(ctx, domain_ctx:, **)
      domain_ctx[:model]       = ctx[:process_model] if ctx.key?(:process_model)
    end

    # TODO: only in a suspend/resume protocol
    def copy_resume_data_to_domain_ctx(ctx, domain_ctx:, **)
      domain_ctx[:resume_data] = ctx[:resume_data] # FIXME: this should be done in endpoint/suspendresume
    end

  end

  puts Trailblazer::Developer.render(SerializingProtocol)
end
#:generic end

# do
#   {Output(:not_found) => Track(:not_found)}
# end
