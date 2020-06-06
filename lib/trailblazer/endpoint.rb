module Trailblazer
  class Endpoint
    # Create an {Endpoint} class with the provided adapter and protocol.
    # This builder also sets up taskWrap filters around the {domain_activity} execution.
    def self.build(protocol:, adapter:, domain_activity:, scope_domain_ctx: true, domain_ctx_filter: nil, &block)

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


      domain_ctx_filter_callable = [[Trailblazer::Activity::TaskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["endpoint.domain_ctx_filter", domain_ctx_filter]]]
      extensions_options[:extensions] << Trailblazer::Activity::TaskWrap::Extension(merge: domain_ctx_filter_callable) if domain_ctx_filter

      app_protocol = Class.new(protocol) do
        step(Subprocess(domain_activity), {inherit: true, id: :domain_activity, replace: :domain_activity,

# FIXME: where does this go?
        }.
          merge(extensions_options).
          merge(instance_exec(&block)) # the block is evaluated in the {Protocol} context.
          )
      end

      Class.new(adapter) do
        step Subprocess(app_protocol), inherit: true, id: :protocol, replace: :protocol
      end # app_adapter

    end

    def self.options_for_scope_domain_ctx()
      {
        input:  ->(ctx, **) { ctx[:domain_ctx] }, # gets automatically Context()'ed.
        output: ->(domain_ctx, **) { {:domain_ctx => domain_ctx} }
      }
    end

    def self.with_or_etc(activity, args, failure_block: nil, success_block: nil) # FIXME: blocks required?
      # args[1] = args[1].merge(focus_on: { variables: [:returned], steps: :invoke_workflow })

      signal, (endpoint_ctx, _ ) = Trailblazer::Developer.wtf?(activity, args)

      # this ctx is passed to the controller block.
      block_ctx = endpoint_ctx[:domain_ctx].merge(endpoint_ctx: endpoint_ctx, signal: signal, errors: endpoint_ctx[:errors]) # DISCUSS: errors?

      # if signal < Trailblazer::Activity::End::Success
      if [:failure, :fail_fast].include?(signal.to_h[:semantic])
        # TODO: test missing failure_block!
        failure_block && failure_block.(block_ctx, **block_ctx) # DISCUSS: this does nothing if no failure_block passed!
      else
        success_block.(block_ctx, **block_ctx)
      end

      # we return the original context???
      return signal, [endpoint_ctx]
    end
  end
end
#     # this is totally WIP as we need to find best practices.
#     # also, i want this to be easily extendable.
#     Matcher = Dry::Matcher.new(
#       present: Dry::Matcher::Case.new( # DISCUSS: the "present" flag needs some discussion.
#         match:   ->(result) { result.success? && result["present"] },
#         resolve: ->(result) { result }),
#       success: Dry::Matcher::Case.new(
#         match:   ->(result) { result.success? },
#         resolve: ->(result) { result }),
#       created: Dry::Matcher::Case.new(
#         match:   ->(result) { result.success? && result["model.action"] == :new }, # the "model.action" doesn't mean you need Model.
#         resolve: ->(result) { result }),
#       not_found: Dry::Matcher::Case.new(
#         match:   ->(result) { result.failure? && result["result.model"] && result["result.model"].failure? },
#         resolve: ->(result) { result }),
#       # TODO: we could add unauthorized here.
#       unauthenticated: Dry::Matcher::Case.new(
#         match:   ->(result) { result.failure? && result["result.policy.default"].failure? }, # FIXME: we might need a &. here ;)
#         resolve: ->(result) { result }),
#       invalid: Dry::Matcher::Case.new(
#         match:   ->(result) { result.failure? && result["result.contract.default"] && result["result.contract.default"].failure? },
#         resolve: ->(result) { result })
#     )

#     # `call`s the operation.
#     def self.call(operation_class, handlers, *args, &block)
#       raise
#       result = operation_class.(*args)
#       new.(result, handlers, &block)
#     end

#     def call(result, handlers=nil, &block)
#       matcher.(result, &block) and return if block_given? # evaluate user blocks first.
#       matcher.(result, &handlers)     # then, generic Rails handlers in controller context.
#     end

#     def matcher
#       Matcher
#     end

#     module Controller
#       # endpoint(Create) do |m|
#       #   m.not_found { |result| .. }
#       # end
#       def endpoint(operation_class, options={}, &block)
#         handlers = Handlers::Rails.new(self, options).()
#         Endpoint.(operation_class, handlers, *options[:args], &block)
#       end
#     end
#   end
# end
