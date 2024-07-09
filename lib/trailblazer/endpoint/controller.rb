module Trailblazer
  class Endpoint
    module Controller
      module State
        module Inherited
          # This should only happen once.
          def self.extended(base)
            state = Declarative::State(
              endpoints:            [Hash.new, {}],
              default_matcher:      [Hash.new, {}],
              ctx:                  [Hash.new, {}],
              options_for_endpoint: [Hash.new, {}],
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

        module DSL
          class DSL
            def initialize
              @hash = {}
            end

            def default_matcher(&block)
              matchers = yield
              # TODO: complain if not hash
              @hash[:default_matcher] = matchers
            end

            def ctx(&block)
              @hash[:ctx] = block
            end

            def options(&block)
              options_for_endpoint = yield
              @hash[:options_for_endpoint] = options_for_endpoint
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
            instance_variable_get(:@state).update!(:options_for_endpoint) { |old_options| options[:options_for_endpoint] } if options[:options_for_endpoint]
          end
        end

        module Config
          def _endpoints
            self.class._endpoints
          end

          module ClassMethods
            def _options_for_endpoint
              instance_variable_get(:@state).get(:options_for_endpoint)
            end

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
        end
      end # State

      # This DSL code is independent of State:
      module DSL # Controller.endpoint
        # Builds and registers an endpoint in a controller class.
        def endpoint(name=nil, **options, &block)
          options = options.merge(protocol_block: block) if block_given?

          build_endpoint(name, **options)
        end

        def build_endpoint(name, domain_activity: name, **options)
          build_options = _options_for_endpoint.merge(domain_activity: domain_activity, **options) # FIXME: this means we must have #_options_for_endpoint defined on this class!

          endpoint = Trailblazer::Endpoint.build(**build_options)

          _endpoints[name.to_s] = endpoint
        end
      end # DSL


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


    end # Controller
  end
end
