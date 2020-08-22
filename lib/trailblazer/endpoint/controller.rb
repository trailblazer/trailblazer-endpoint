module Trailblazer
  class Endpoint
    module Controller
      def self.extended(extended)
        extended.extend Trailblazer::Endpoint::Options::DSL
        extended.extend Trailblazer::Endpoint::Options::DSL::Inherit
        extended.extend Trailblazer::Endpoint::Options
        extended.extend DSL::Endpoint

        extended.include InstanceMethods

        # DISCUSS: hmm
        extended.directive :generic_options,          ->(*) { Hash.new } # for Controller::endpoint
        extended.directive :options_for_flow_options, ->(*) { Hash.new }
        extended.directive :options_for_endpoint,     ->(*) { Hash.new }
        extended.directive :options_for_domain_ctx,   ->(*) { Hash.new }
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

        end # Process

        # The three default handlers for {Endpoint::with_or_etc}
        # @experimental
        module DefaultBlocks
          def self.extended(extended)
            extended.directive :options_for_block_options, Controller.method(:options_for_block_options)
          end
        end
        # @experimental
        module DefaultParams
          def self.extended(extended)
            extended.directive :options_for_domain_ctx, ->(ctx, controller:, **) { {params: controller.params} }
          end
        end

      end # Rails

      module DSL
        module Endpoint
          def self.extended(extended)
            extended.directive(:endpoints, ->(*) { {} })
          end

          def endpoint(name, **options, &block)
            options = options.merge(protocol_block: block) if block_given?

            return generic_endpoint_config(**name, **options) if name.is_a?(Hash)
            endpoint_config(name, **options)
          end

          def generic_endpoint_config(protocol:, adapter:, **options)
            self.singleton_class.define_method :generic_options do |ctx,**|
              {
                protocol: protocol,
                adapter: adapter,
                **options
              }
            end

            directive :generic_options, method(:generic_options) # FIXME: do we need this?
          end

          def endpoint_config(name, **options)
            build_options = options_for(:generic_options, {}).merge(options) # DISCUSS: why don't we add this as another directive option/step?

            endpoint = Trailblazer::Endpoint.build(build_options)

            directive :endpoints, ->(*) { {name => endpoint} }
          end

        end
      end

      module InstanceMethods
        def endpoint(name, **action_options, &block)
          endpoint = endpoint_for(name)

          invoke_endpoint_with_dsl(endpoint: endpoint, **action_options, &block)
        end

        def endpoint_for(name)
          self.class.options_for(:endpoints, {})[name]
        end

        def invoke_endpoint_with_dsl(options, &block)
          _dsl = Trailblazer::Endpoint::DSL::Runtime.new(options, block) # provides #Or etc, is returned to {Controller#call}
        end

      # somehow different

        def advance_endpoint_for_controller(endpoint:, block_options:, **action_options)
          domain_ctx, endpoint_options, flow_options = compile_options_for_controller(**action_options) # controller-specific, get from directives.

          endpoint_options = endpoint_options.merge(action_options) # DISCUSS

          Endpoint::Controller.advance_endpoint(
            endpoint:      endpoint,
            block_options: block_options,

            domain_ctx:       domain_ctx,
            endpoint_options: endpoint_options,
            flow_options:     flow_options,
          )
        end

        # Requires {options_for}
        def compile_options_for_controller(options_for_domain_ctx: nil, **action_options)
          flow_options     = self.class.options_for(:options_for_flow_options, controller: self, **action_options)
          endpoint_options = self.class.options_for(:options_for_endpoint, controller: self, **action_options) # "class level"
          domain_ctx       = options_for_domain_ctx || self.class.options_for(:options_for_domain_ctx, controller: self, **action_options)

          return domain_ctx, endpoint_options, flow_options
        end
      end

      # Ultimate low-level entry point.
      # Remember that you don't _have_ to use Endpoint.with_or_etc to invoke an endpoint.
      def self.advance_endpoint(endpoint:, block_options:, domain_ctx:, endpoint_options:, flow_options:)

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

      # Default blocks for the {Adapter}.
      def self.options_for_block_options(ctx, controller:, **)
        {
          success_block:          ->(ctx, endpoint_ctx:, **) { controller.head 200 },
          failure_block:          ->(ctx, **) { controller.head 422 },
          protocol_failure_block: ->(ctx, endpoint_ctx:, **) { controller.head endpoint_ctx[:status] }
        }
      end

    end # Controller
  end
end
