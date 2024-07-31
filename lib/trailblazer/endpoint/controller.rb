module Trailblazer
  class Endpoint
    module Controller
      def self.module(framework: :rails)
        Module.new do
          def self.included(includer)
            # TODO: this is  for Rails-style controllers with class-level configuration
            #       and instance method-level runtime logic.
            includer.extend Trailblazer::Endpoint::Controller::DSL # ::endpoint
            includer.include Trailblazer::Endpoint::Controller::Runtime # #invoke

            includer.extend Trailblazer::Endpoint::Controller::State::Inherited # ::endpoint

            # DISCUSS: necessary API to store/retrieve config values.
            includer.include Trailblazer::Endpoint::Controller::State::Config # #_endpoints
            includer.extend Trailblazer::Endpoint::Controller::State::Config::ClassMethods #_default_matcher_for_endpoint
            includer.extend Trailblazer::Endpoint::Controller::State::DSL # endpoint {}
          end
        end
      end

      module State
        module Inherited
          # This should only happen once.
          def self.extended(base)
            state = Declarative::State(
              endpoints:            [Hash.new, {}],
              default_matcher:      [Hash.new, {}],
              ctx:                  [->(*) { {} }, {}], # empty default hash for {ctx}.
              # options_for_endpoint: [{adapter: Trailblazer::Endpoint::Adapter}, {}],
              options_for_endpoint: [{}, {}],
              flow_options:         [->(*) { {} }, {}],
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

            def flow_options(&block)
              @hash[:flow_options] = block
            end

            def self.call(&block)
              dsl = new
              dsl.instance_exec(&block)
              dsl.instance_variable_get(:@hash)
            end
          end

          # Controller DSL when used without a concrete endpoint constant.
          def endpoint(name = nil, **options, &block)
            return super if name

            options = DSL.call(&block)

            # TODO: what other options keys do we support?
            instance_variable_get(:@state).update!(:default_matcher)  { |old_matchers| old_matchers.merge(options[:default_matcher]) } if options[:default_matcher]
            # instance_variable_get(:@state).update!(:default_matcher)  { |old_matchers| options[:default_matcher] } if options[:default_matcher]
            instance_variable_get(:@state).update!(:options_for_endpoint) { |old_options| options[:options_for_endpoint] } if options[:options_for_endpoint]
            instance_variable_get(:@state).update!(:ctx)              { |old_ctx_options| options[:ctx] } if options[:ctx]
            instance_variable_get(:@state).update!(:flow_options) { |old_options| options[:flow_options] } if options[:flow_options]
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

          # Evaluated at runtime.
          def _options_for_endpoint_ctx
            instance_exec &self.class.instance_variable_get(:@state).get(:ctx)
          end

          # Evaluated at runtime.
          def _flow_options(**options)
            instance_exec &self.class.instance_variable_get(:@state).get(:flow_options)
          end
        end
      end # State

      # BUILD DSL
      # This DSL code is independent of State:
      module DSL # Controller.endpoint
        # Builds and registers an endpoint in a controller class.
        def endpoint(name=nil, **options, &block) # TODO: test block
          options = options.merge(protocol_block: block)

          # TODO: move this code somewhere else
          options = DSL.process_fast_track_to_railway(name, **options)


          build_endpoint(name, **options)
        end

        def build_endpoint(name, domain_activity: name, options_for_domain_activity: {}, **options)



          build_options = _options_for_endpoint.merge(domain_activity: domain_activity, **options) # FIXME: this means we must have #_options_for_endpoint defined on this class!

          endpoint = Trailblazer::Endpoint.build(**build_options, options_for_domain_activity: options_for_domain_activity)

          _endpoints[name.to_s] = endpoint
        end



        # TODO: use Normalizer architecture.
        def self.process_fast_track_to_railway(name, fast_track_to_railway: nil, **options)
          return options unless fast_track_to_railway

          options_for_domain_activity = {}

          _protocol = Trailblazer::Activity::Railway # FIXME: take :protocol kw arg.

          # wire fast track termini to railway termini
          options_for_domain_activity = options_for_domain_activity.merge(
            _protocol.Output(:fail_fast) =>  _protocol.End(:failure),
            _protocol.Output(:pass_fast) =>  _protocol.End(:success),
          )

          options.merge(options_for_domain_activity: options_for_domain_activity)
        end
      end # DSL


      # Runtime code uses instance methods from {Config} to retrieve necessary dependencies,
      # nothing else.
      module Runtime
        def invoke(operation, **options, &matcher_block)
          flow_options  = _flow_options(**options)
          ctx           = _options_for_endpoint_ctx.merge(options)  # FIXME: pass **options

          action_protocol = _endpoints.fetch(operation.to_s)

          default_matcher = _default_matcher_for_endpoint()

          Endpoint::Runtime.(ctx, protocol: action_protocol, default_matcher: default_matcher, matcher_context: self, flow_options: flow_options, &matcher_block)
        end
      end


    end # Controller
  end
end
