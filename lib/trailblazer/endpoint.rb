module Trailblazer
  class Endpoint
    # Create an {Endpoint} class with the provided adapter and protocol.
    # This builder also sets up taskWrap filters around the {domain_activity} execution.
    def self.build(protocol:, adapter:, domain_activity:, protocol_block: ->(*) { Hash.new })
      # special considerations around the {domain_activity} and its taskWrap:
      #
      #  1. domain_ctx_filter (e.g. to filter {current_user})
      #  2. :input (scope {:domain_ctx})
      #  3. call (domain_activity)
      #  4. :output
      #  5. save return signal

      app_protocol = build_protocol(protocol, domain_activity: domain_activity)

      # puts Trailblazer::Developer.render(app_protocol)

      Class.new(adapter) do
        step(Subprocess(app_protocol), {inherit: true, id: :protocol, replace: :protocol})
      end # app_adapter

    end

    # @private
    # TODO: move to Protocol.
    def self.build_protocol(protocol, domain_activity:, protocol_block:)
      Class.new(protocol) do
        step(Subprocess(domain_activity), {inherit: true, replace: :domain_activity,}.
          # merge(extensions_options).
          merge(instance_exec(&protocol_block)) # the block is evaluated in the {Protocol} context.
        )
      end
    end

    def self.scope_domain_ctx
      {
        Activity::Railway.In()  => ->(ctx, **) { ctx[:domain_ctx] }, # gets automatically Context()'ed.
        Activity::Railway.Out() => ->(domain_ctx, **) { {:domain_ctx => domain_ctx} }
      }
    end

    #@ For WORKFLOW and operations. not sure this method will stay here.
    def self.arguments_for(domain_ctx:, flow_options:, circuit_options: {}, **endpoint_options)
      # we don't have to create the Ctx wrapping explicitly here. this is done via `:input`.
      # domain_ctx      = Trailblazer::Context::IndifferentAccess.build(domain_ctx, {}, [domain_ctx, flow_options], circuit_options)

      [
        [
          {
              domain_ctx:                     domain_ctx, # DISCUSS: is this where {:resume_data} comes in?
              # process_model_class:            process_model_class,
              # process_model_from_resume_data: process_model_from_resume_data,
              # find_process_model:             find_process_model,
              # encrypted_resume_data:          encrypted_resume_data,

              # cipher_key:                     cipher_key,
              **endpoint_options,
          },
          flow_options
        ],
        circuit_options
      ]
    end

    # FIXME: name will change! this is for controllers, only!
    def self.advance_from_controller(endpoint, success_block:, failure_block:, protocol_failure_block:, **argument_options)
      args = Trailblazer::Endpoint.arguments_for(argument_options)

      signal, (ctx, _ ) = Trailblazer::Endpoint.with_or_etc(
        endpoint,
        args[0], # [ctx, flow_options]

        success_block:          success_block,
        failure_block:          failure_block,
        protocol_failure_block: protocol_failure_block,
      )

      ctx
    end
  end
end
#       created: Dry::Matcher::Case.new(
#         match:   ->(result) { result.success? && result["model.action"] == :new }, # the "model.action" doesn't mean you need Model.
#         resolve: ->(result) { result }),
#       not_found: Dry::Matcher::Case.new(
#         match:   ->(result) { result.failure? && result["result.model"] && result["result.model"].failure? },
#         resolve: ->(result) { result }),
#       # TODO: we could add unauthorized here.


require "trailblazer/endpoint/protocol"
require "trailblazer/endpoint/adapter"
require "trailblazer/endpoint/matcher"
# require "trailblazer/endpoint/dsl"
require "trailblazer/endpoint/controller"
require "trailblazer/endpoint/options"
require "trailblazer/endpoint/protocol/controller"
require "trailblazer/endpoint/protocol/find_process_model"
require "trailblazer/endpoint/protocol/cipher"
