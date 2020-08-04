module Trailblazer
  class Endpoint
    module Controller
      def self.extended(extended)
        extended.extend Trailblazer::Endpoint::Options::DSL
        extended.extend Trailblazer::Endpoint::Options::DSL::Inherit
        extended.extend Trailblazer::Endpoint::Options
      end

      module Rails
        module Process
          def send_action(action_name)
      puts "@@@@@>>>>>>> #{action_name.inspect}"

            dsl = send(action_name) # call the actual controller action.

            options, block_options = dsl.to_args(self.class.options_for(:options_for_block_options, controller: self)) # {success_block:, failure_block:, protocol_failure_block:}
            # now we know the authorative blocks

            advance_endpoint_for_controller(**options, block_options: block_options)
          end

        end
      end # Rails

    def endpoint(name, &block)
      endpoint = endpoint_for(name)

      invoke_endpoint_with_dsl(endpoint: endpoint, &block)
    end

    def invoke_endpoint_with_dsl(options, &block)
      _dsl = Trailblazer::Endpoint::DSL::Runtime.new(options, block) # provides #Or etc, is returned to {Controller#call}
    end

      module_function

      def advance_endpoint_for_controller(endpoint:, block_options:, **action_options)
        domain_ctx, endpoint_options, flow_options = compile_options_for_controller(**action_options) # controller-specific, get from directives.

        endpoint_options = endpoint_options.merge(action_options) # DISCUSS

        advance_endpoint(
          endpoint:      endpoint,
          block_options: block_options,

          domain_ctx:       domain_ctx,
          endpoint_options: endpoint_options,
          flow_options:     flow_options,
        )
      end

      # Ultimate low-level entry point.
      # Remember that you don't _have_ to use Endpoint.with_or_etc to invoke an endpoint.
      def advance_endpoint(endpoint:, block_options:, domain_ctx:, endpoint_options:, flow_options:)

        # build Context(ctx),
        args, _ = Trailblazer::Endpoint.arguments_for(
          domain_ctx:   domain_ctx,
          flow_options: flow_options,
          **endpoint_options,
        )

        signal, (ctx, _ ) = Trailblazer::Endpoint.with_or_etc(
          endpoint,
          args, # [ctx, flow_options]

          **block_options,
          # success_block: success_block,
          # failure_block: failure_block,
          # protocol_failure_block: protocol_failure_block,
        )
      end

      # Requires {options_for}
      def compile_options_for_controller(options_for_domain_ctx: nil, **action_options)
        domain_ctx       = options_for_domain_ctx || self.class.options_for(:options_for_domain_ctx, controller: self, **action_options)
        endpoint_options = self.class.options_for(:options_for_endpoint, controller: self, **action_options) # "class level"
        flow_options     = self.class.options_for(:options_for_flow_options, controller: self, **action_options)

        return domain_ctx, endpoint_options, flow_options
      end
    end # Controller
  end
end
