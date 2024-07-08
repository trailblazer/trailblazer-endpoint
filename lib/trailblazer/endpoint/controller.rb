module Trailblazer
  class Endpoint
    module Controller
      module DSL # Controller.endpoint

        module Inherited # FIXME: move one level up!
          # This should only happen once.
          def self.extended(base)
            # base.extend(Inherited)

            # base.instance_variable_set(:@endpoints, {})  # FIXME: implement inheritance!
            state = Declarative::State(
              endpoints:        [Hash.new, {}],
              default_matcher:  [Hash.new, {}],
              ctx:              [Hash.new, {}],
            )
            base.initialize!(state)
          end

          def initialize!(state)
            @state = state
          end

          def inherited(inheriter) # FIXME: move one level up!
            super

            inheriter.initialize!(@state.copy)
          end
        end



# This DSL code is independent of State:
        # Builds and registers an endpoint in a controller class.
        def endpoint(name=nil, **options, &block)
          options = options.merge(protocol_block: block) if block_given?

          build_endpoint(name, **options)
        end

        def build_endpoint(name, domain_activity: name, **options)
          build_options = options_for_endpoint.merge(domain_activity: domain_activity, **options) # FIXME: this means we must have #options_for_endpoint defined on this class!

          endpoint = Trailblazer::Endpoint.build(**build_options)

          _endpoints[name.to_s] = endpoint
        end
      end # DSL

      module Config
        def _endpoints
          self.class._endpoints
        end

        module ClassMethods
          # def _update_endpoints!(name, endpoint)
          #   instance_variable_get(:@state).update!(:endpoints) { |old_endpoints| old_endpoints.merge(name.to_s => endpoint) }
          # end

          def _endpoints
            instance_variable_get(:@state).get(:endpoints)
          end
        end

        def _default_matcher_for_endpoint
          self.class.instance_variable_get(:@state).get(:default_matcher)
        end

        def _options_for_endpoint_ctx
          instance_exec &self.class.instance_variable_get(:@state).get(:ctx)
        end


        module DSL
          class DSL
            def initialize
              @hash = {}
            end

            def default_matcher(matchers)
              # TODO: complain if not hash
              @hash[:default_matcher] = matchers
            end

            def ctx(&block)
              @hash[:ctx] = block
            end

            def self.call(&block)
              dsl = new
              dsl.instance_exec(&block)
              dsl.instance_variable_get(:@hash)
            end
          end
          # Controller DSL when used without a concrete endpoint constant.
          def endpoint(*args, &block)
            return super unless args.size == 0

            options = DSL.call(&block)

            # TODO: what other options keys do we support?
            instance_variable_get(:@state).update!(:default_matcher)  { |old_matchers| old_matchers.merge(options[:default_matcher]) } if options[:default_matcher]
            instance_variable_get(:@state).update!(:ctx)              { |old_ctx_options| options[:ctx] } if options[:ctx]
          end
        end
      end

      # Runtime code uses instance methods from {Config} to retrieve necessary dependencies,
      # nothing else.
      module Runtime
        def invoke(operation, **options, &matcher_block)
          options = _options_for_endpoint_ctx.merge(options)
          ctx = options  # FIXME! add real Context!

          action_adapter = _endpoints.fetch(operation.to_s)

          # FIXME: do at compile time
          # default_matcher = self.class.instance_variable_get(:@default_matcher)
          default_matcher = _default_matcher_for_endpoint() # DISCUSS: this dictates the existence of this method.

          Endpoint::Runtime.(ctx, adapter: action_adapter, default_matcher: default_matcher, matcher_context: self, &matcher_block)
        end
      end

      # def self.extended(extended)
      #   extended.extend Trailblazer::Endpoint::Options::DSL           # ::directive
      #   extended.extend Trailblazer::Endpoint::Options::DSL::Inherit
      #   extended.extend Trailblazer::Endpoint::Options                # ::options_for
      #   extended.extend DSL::Endpoint

      #   extended.include InstanceMethods # {#endpoint_for}

      #   # DISCUSS: hmm
      #   extended.directive :generic_options,          ->(*) { Hash.new } # for Controller::endpoint
      #   extended.directive :options_for_flow_options, ->(*) { Hash.new }
      #   extended.directive :options_for_endpoint,     ->(*) { Hash.new }
      #   extended.directive :options_for_domain_ctx,   ->(*) { Hash.new }
      # end

      # # @experimental
      # # TODO: test application_controller with and without dsl/api

      # def self.module(framework: :rails, api: false, dsl: false, application_controller: false)
      #   if application_controller && !api && !dsl # FIXME: not tested! this is useful for an actual AppController with block_options or flow_options settings, "globally"
      #     Module.new do
      #       def self.included(includer)
      #         includer.extend(Controller) # only ::directive and friends.
      #       end
      #     end
      #   elsif api
      #     Module.new do
      #       @application_controller = application_controller
      #       def self.included(includer)
      #         if @application_controller
      #           includer.extend Controller
      #         end
      #         includer.include(InstanceMethods::API)
      #       end
      #     end
      #   elsif dsl
      #     Module.new do
      #       @application_controller = application_controller
      #       def self.included(includer)
      #         if @application_controller
      #           includer.extend Controller
      #         end
      #         includer.include Trailblazer::Endpoint::Controller::InstanceMethods::DSL
      #         includer.include Trailblazer::Endpoint::Controller::Rails
      #         includer.extend Trailblazer::Endpoint::Controller::Rails::DefaultBlocks
      #         includer.extend Trailblazer::Endpoint::Controller::Rails::DefaultParams
      #         includer.include Trailblazer::Endpoint::Controller::Rails::Process
      #       end
      #     end # Module
      #   else
      #     raise
      #   end
      # end

      module X___DSL
        module Endpoint
          def self.extended(extended)
            extended.directive(:endpoints, ->(*) { {} })
          end

          # Builds and registers an endpoint in a controller class.
          def endpoint(name=nil, **options, &block)
            options = options.merge(protocol_block: block) if block_given?

            return generic_endpoint_config(**options) if name.nil?

            build_endpoint(name, **options)
          end

          # Configures generic {:adapter}, {:protocol}, etc.
          def generic_endpoint_config(**options)
            self.singleton_class.define_method :generic_options do |ctx,**|
              {
                **options
              }
            end

            directive :generic_options, method(:generic_options) # FIXME: do we need this?
          end

          def build_endpoint(name, domain_activity: name, **options)
            build_options = options_for(:generic_options, {}).merge(domain_activity: domain_activity, **options) # DISCUSS: why don't we add this as another directive option/step?

            endpoint = Trailblazer::Endpoint.build(**build_options)

            directive :endpoints, ->(*) { {name.to_s => endpoint} }
          end

        end
      end

      # module InstanceMethods
      #   # Returns object link between compile-time and run-time config
      #   def config_source
      #     self.class
      #   end

      #   def endpoint_for(name)
      #     config_source.options_for(:endpoints, {}).fetch(name.to_s) # TODO: test non-existant endpoint
      #   end

      #   module DSL
      #     def endpoint(name, **action_options, &block)
      #       action_options = {controller: self}.merge(action_options) # FIXME: redundant with {API#endpoint}

      #       endpoint = endpoint_for(name)

      #       # raise name.inspect unless block_given?
      #       # TODO: check {dsl: false}
      #       # unless block_given? # FIXME
      #       #   config_source = self.class # FIXME
      #       #   block_options = config_source.options_for(:options_for_block_options, **action_options)
      #       #   block_options = Trailblazer::Endpoint::Options.merge_with(action_options, block_options)

      #       #   signal, (ctx, _) = Trailblazer::Endpoint::Controller.advance_endpoint_for_controller(
      #       #     endpoint:       endpoint,
      #       #     block_options:  block_options,
      #       #     config_source:  config_source,
      #       #     **action_options
      #       #   )

      #       #   return ctx
      #       # end


      #       invoke_endpoint_with_dsl(endpoint: endpoint, **action_options, &block)
      #     end

      #     def invoke_endpoint_with_dsl(options, &block)
      #       _dsl = Trailblazer::Endpoint::DSL::Runtime.new(options, block) # provides #Or etc, is returned to {Controller#call}
      #     end
      #   end

      #   module API
      #     def endpoint(name, **action_options)
      #       endpoint = endpoint_for(name)
      #       action_options = {controller: self}.merge(action_options) # FIXME: redundant with {InstanceMethods#endpoint}

      #       block_options = config_source.options_for(:options_for_block_options, **action_options)
      #       block_options = Trailblazer::Endpoint::Options.merge_with(action_options, block_options)

      #       signal, (ctx, _) = Trailblazer::Endpoint::Controller.advance_endpoint_for_controller(
      #         endpoint:       endpoint,
      #         block_options:  block_options,
      #         config_source:  config_source,
      #         **action_options
      #       )

      #       ctx
      #     end
      #   end # API
      # end


      # def self.advance_endpoint_for_controller(endpoint:, block_options:, **action_options)
      #   domain_ctx, endpoint_options, flow_options = compile_options_for_controller(**action_options) # controller-specific, get from directives.

      #   endpoint_options = endpoint_options.merge(action_options) # DISCUSS

      #   Endpoint::Controller.advance_endpoint(
      #     endpoint:      endpoint,
      #     block_options: block_options,

      #     domain_ctx:       domain_ctx,
      #     endpoint_options: endpoint_options,
      #     flow_options:     flow_options,
      #   )
      # end

      # def self.compile_options_for_controller(options_for_domain_ctx: nil, config_source:, **action_options)
      #   flow_options     = config_source.options_for(:options_for_flow_options, **action_options)
      #   endpoint_options = config_source.options_for(:options_for_endpoint, **action_options) # "class level"
      #   domain_ctx       = options_for_domain_ctx || config_source.options_for(:options_for_domain_ctx, **action_options)

      #   return domain_ctx, endpoint_options, flow_options
      # end

      # # Ultimate low-level entry point.
      # # Remember that you don't _have_ to use Endpoint.with_or_etc to invoke an endpoint.
      # def self.advance_endpoint(endpoint:, block_options:, domain_ctx:, endpoint_options:, flow_options:)

      #   # build Context(ctx),
      #   args, _ = Trailblazer::Endpoint.arguments_for(
      #     domain_ctx:   domain_ctx,
      #     flow_options: flow_options,
      #     **endpoint_options,
      #   )

      #   signal, (ctx, _ ) = Trailblazer::Endpoint.with_or_etc(
      #     endpoint,
      #     args, # [ctx, flow_options]

      #     **block_options,
      #     # success_block: success_block,
      #     # failure_block: failure_block,
      #     # protocol_failure_block: protocol_failure_block,
      #   )
      # end

      # # Default blocks for the {Adapter}.
      # def self.options_for_block_options(ctx, controller:, **)
      #   {
      #     success_block:          ->(ctx, endpoint_ctx:, **) { controller.head 200 },
      #     failure_block:          ->(ctx, **) { controller.head 422 },
      #     protocol_failure_block: ->(ctx, endpoint_ctx:, **) { controller.head endpoint_ctx[:status] }
      #   }
      # end

    end # Controller
  end
end
