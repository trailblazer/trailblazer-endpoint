module Trailblazer
  class Endpoint
    # Create an {Endpoint} class with the provided adapter and protocol.
    # This builder also sets up taskWrap filters around the {domain_activity} execution.
    def self.build(protocol:, adapter:, domain_activity:, scope_domain_ctx: true, protocol_block: ->(*) { Hash.new },
      serialize: false, # TODO: plug-in, not hardcoded!
      deserialize: false,# TODO: plug-in, not hardcoded!
      find_process_model: false, # TODO: plug-in, not hardcoded!
      deserialize_process_model_id_from_resume_data: false # TODO: plug-in, not hardcoded!
      )
      # special considerations around the {domain_activity} and its taskWrap:
      #
      #  1. domain_ctx_filter (e.g. to filter {current_user})
      #  2. :input (scope {:domain_ctx})
      #  3. call (domain_activity)
      #  4. :output
      #  5. save return signal


      extensions_options = {
        extensions: [Trailblazer::Activity::TaskWrap::Extension(merge: Trailblazer::Endpoint::Protocol::Domain.extension_for_terminus_handler)],
      }

      # scoping: {:domain_ctx} becomes ctx
      extensions_options.merge!(Endpoint.options_for_scope_domain_ctx) if scope_domain_ctx # TODO: test flag

      app_protocol = build_protocol(protocol, domain_activity: domain_activity, extensions_options: extensions_options, protocol_block: protocol_block, serialize: serialize, deserialize: deserialize,
        find_process_model: find_process_model, deserialize_process_model_id_from_resume_data: deserialize_process_model_id_from_resume_data
        )

      # puts Trailblazer::Developer.render(app_protocol)

      Class.new(adapter) do
        step(Subprocess(app_protocol), {inherit: true, id: :protocol, replace: :protocol})
      end # app_adapter

    end

    # @private
    def self.build_protocol(protocol, domain_activity:, extensions_options:, protocol_block:, serialize:, deserialize:, find_process_model:, deserialize_process_model_id_from_resume_data:)
      Class.new(protocol) do
        if serialize
          Protocol::Controller.insert_serialize_steps!(self)
        end

        if deserialize
          Protocol::Controller.insert_deserialize_steps!(self)
        end

        if serialize || deserialize
          Protocol::Controller.insert_copy_to_domain_ctx!(self, {:resume_data => :resume_data})
        end

        if find_process_model
          Protocol::Controller.insert_find_process_model!(self, before: :policy) # TODO: test before: :policy
        end

        if deserialize_process_model_id_from_resume_data
          pass Protocol::Controller.method(:deserialize_process_model_id_from_resume_data), after: :deserialize_resume_data, magnetic_to: :deserialize, Output(:success) => Track(:deserialize)
        end

        step(Subprocess(domain_activity), {inherit: true, id: :domain_activity, replace: :domain_activity,

# FIXME: where does this go?
        }.
          merge(extensions_options).
          merge(instance_exec(&protocol_block)) # the block is evaluated in the {Protocol} context.
        )
      end
    end

    def self.options_for_scope_domain_ctx()
      {
        input:  ->(ctx, **) { ctx[:domain_ctx] }, # gets automatically Context()'ed.
        output: ->(domain_ctx, **) { {:domain_ctx => domain_ctx} }
      }
    end

    # Runtime
    # Invokes the endpoint for you and runs one of the three outcome blocks.
    def self.with_or_etc(activity, args, failure_block:, success_block:, protocol_failure_block:, invoke: Trailblazer::Activity::TaskWrap.method(:invoke))
    # def self.with_or_etc(activity, args, failure_block:, success_block:, protocol_failure_block:, invoke: Trailblazer::Developer.method(:wtf?))

      # args[1] = args[1].merge(focus_on: { variables: [:returned], steps: :invoke_workflow })

      # signal, (endpoint_ctx, _ ) = Trailblazer::Developer.wtf?(activity, args)
      signal, (endpoint_ctx, _ ) = invoke.call(activity, args) # translates to Trailblazer::Developer.wtf?(activity, args)

      # this ctx is passed to the controller block.
      block_ctx = endpoint_ctx[:domain_ctx].merge(endpoint_ctx: endpoint_ctx, signal: signal, errors: endpoint_ctx[:errors]) # DISCUSS: errors? status?

      # if signal < Trailblazer::Activity::End::Success
      adapter_terminus_semantic = signal.to_h[:semantic]

      executed_block =
        if adapter_terminus_semantic    == :success
          success_block
        elsif adapter_terminus_semantic == :fail_fast
          protocol_failure_block
        else
          failure_block
        end

      executed_block.(block_ctx, **block_ctx)

      # we return the original context???
      return signal, [endpoint_ctx]
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
require "trailblazer/endpoint/dsl"
require "trailblazer/endpoint/controller"
require "trailblazer/endpoint/options"
require "trailblazer/endpoint/protocol/controller"
require "trailblazer/endpoint/protocol/find_process_model"
require "trailblazer/endpoint/protocol/cipher"
