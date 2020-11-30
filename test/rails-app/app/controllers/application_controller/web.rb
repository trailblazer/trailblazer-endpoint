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


  module Advance___
    module Controller #< Activity::Railway
      module_function
        def decrypt?(ctx, encrypted_resume_data:, **)
          encrypted_resume_data
        end

        def deserialize_resume_data(ctx, decrypted_value:, **)
          ctx[:resume_data] = JSON.parse(decrypted_value)
        end

        def deserialize_process_model?(ctx, process_model_from_resume_data:, **)
          process_model_from_resume_data
        end

        def deserialize_process_model_id(ctx, resume_data:, **)
          ctx[:process_model_id] = resume_data["id"] # DISCUSS: overriding {:process_model_id}?
        end

        def encrypt?(ctx, domain_ctx:, **)
          ctx[:suspend_data] = domain_ctx[:suspend_data]
        end

        def serialize_suspend_data(ctx, suspend_data:, **)
          ctx[:serialized_suspend_data] = JSON.dump(suspend_data)
        end

      def insert_serializing!(activity, around_activity_id:, deserialize_before: :policy, serialize_after: :domain_activity)
        activity.module_eval do
          step Advance___::Controller.method(:decrypt?), Trailblazer::Activity::Railway.Output(:failure) => Trailblazer::Activity::Railway.Id(deserialize_before), id: :decrypt?        , before: deserialize_before
          step Trailblazer::Workflow::Cipher.method(:decrypt_value), id: :decrypt,
              input: {cipher_key: :cipher_key, encrypted_resume_data: :encrypted_value}                   , before: deserialize_before,
              Output(:failure) => Track(:success), Output(:success) => Path(connect_to: Track(:success), track_color: :deserialize, before: deserialize_before) do # usually, Path goes into {policy}

            step Advance___::Controller.method(:deserialize_resume_data), id: :deserialize_resume_data
            # DISCUSS: unmarshall?
            # step Advance___::Controller.method(:deserialize_process_model_id?), id: :deserialize_process_model_id?, activity.Output(Trailblazer::Activity::Left, :failure) => activity.Id(around_activity_id)
            # step Advance___::Controller.method(:deserialize_process_model_id), id: :deserialize_process_model_id

            step ->(*) { true } # FIXME: otherwise we can't insert an element AFTER :deserialize_resume_data
          end

          # step Subprocess(around_activity), id: around_activity_id, Trailblazer::Activity::Railway.Output(:not_found) => End(:not_found)


            # FIXME: reverse order for insertion
          step Trailblazer::Workflow::Cipher.method(:encrypt_value), id: :encrypt                                                , after: serialize_after,
              input: {cipher_key: :cipher_key, serialized_suspend_data: :value}, output: {encrypted_value: :encrypted_suspend_data}
          step Advance___::Controller.method(:serialize_suspend_data), id: :serialize_suspend_data                                , after: serialize_after
          step Advance___::Controller.method(:encrypt?), id: :encrypt?                                                            , after: serialize_after,
            Output(:failure) => End(:success)
        end
      end
    end
    # end
  end

  require "trailblazer/workflow"
  class SerializingProtocol < Protocol
    Advance___::Controller.insert_serializing!(self, around_activity_id: :domain_activity)

    pass :copy_process_model_to_domain_ctx, before: :domain_activity
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
