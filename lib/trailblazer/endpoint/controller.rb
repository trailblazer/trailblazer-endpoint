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

      def self.module!(target, canonical_invoke:, **options) # TODO: use {Kernel#__} as a default {canonical_invoke}.
        target.include(self.module(**options))

        target.define_method(:invoke) do |*args,  **kws, &block|
          super(*args, runtime_call: canonical_invoke, **kws, &block)
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
              options_for_endpoint: [{}, {}],
              flow_options:         [->(*) { {} }, {}],
              invoke:               [->(*) { {} }, {}],
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

            def invoke(&block)
              @hash[:invoke] = block
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
            instance_variable_get(:@state).update!(:invoke) { |old_options| options[:invoke] } if options[:invoke]
          end
        end

        module Config
          def _endpoints
            self.class._endpoints
          end

          module ClassMethods
            def _options_for_endpoint
              @state.get(:options_for_endpoint)
            end

            def _endpoints
              @state.get(:endpoints)
            end

            def _default_matcher_for_endpoint
              @state.get(:default_matcher)
            end

            def _options_for_endpoint_ctx(**options)
              @state.get(:ctx).call(**options)
            end

            def _flow_options(**options)
              @state.get(:flow_options).call(**options)
            end

            def _invoke_options(**)
              @state.get(:invoke).call() # TODO: pass options, {:domain_activity} etc.
            end
          end

          def _default_matcher_for_endpoint
            self.class._default_matcher_for_endpoint
          end

          # Evaluated at runtime.
          def _options_for_endpoint_ctx(**options)
            self.class._options_for_endpoint_ctx(**options)
          end

          # Evaluated at runtime.
          def _flow_options(**options)
            self.class._flow_options(**options)
          end

          # Evaluated at runtime.
          def _invoke_options(**options)
            self.class._invoke_options(**options)
          end
        end
      end # State

      # BUILD DSL
      # This DSL code is independent of State:
      module DSL # Controller.endpoint
        # Builds and registers an endpoint in a controller class.
        def endpoint(name, domain_activity: name, **options, &block) # TODO: test block

          # TODO: move this code somewhere else
          options = DSL.merge_class_and_user_options(self, **options)
          options = DSL.normalize_protocol_block(**options, block: block)

          options_for_domain_activity, options = DSL.normalize_options(domain_activity: domain_activity, **options)

          options_for_domain_activity = DSL.process_fast_track_to_railway(name, **options_for_domain_activity, domain_activity: domain_activity) # scope: {options_for_domain_activity}

          options = DSL.process_protocol_block(name, options_for_domain_activity: options_for_domain_activity, domain_activity: domain_activity, **options)

          build_endpoint(name, **options)
        end

        def build_endpoint(name, **build_options)
          endpoint = Trailblazer::Endpoint.build(**build_options)

          _endpoints[name.to_s] = endpoint
        end

        def self.merge_class_and_user_options(controller, **options)
          _options = controller._options_for_endpoint.merge(**options) # DISCUSS: this means we must have #_options_for_endpoint defined on this class!
        end

        def self.normalize_protocol_block(block:, protocol_block: nil, **options)
          options.merge(
            protocol_block: block || protocol_block
          )
        end

        # Dissect build options and {options_for_domain_activity}.
        def self.normalize_options(fast_track_to_railway: nil, **options)
          return {fast_track_to_railway: fast_track_to_railway}, options
        end

        # TODO: use Normalizer architecture.
        # If option is set, add Wiring API routings.
        #
        # Scope: {options_for_domain_activity}.
        def self.process_fast_track_to_railway(name, fast_track_to_railway:, **options)
          return options unless fast_track_to_railway

          _protocol = Trailblazer::Activity::Railway # FIXME: take :protocol kw arg.

          # wire fast track termini to railway termini
          options_for_domain_activity = {
            _protocol.Output(:fail_fast) =>  _protocol.End(:failure),
            _protocol.Output(:pass_fast) =>  _protocol.End(:success),
          }.merge(options)
        end

        def self.process_protocol_block(name, protocol_block: nil, domain_activity:, options_for_domain_activity:, **options)
          return options.merge(domain_activity: domain_activity, options_for_domain_activity: options_for_domain_activity) unless protocol_block

          options_from_block = domain_activity.instance_exec(&protocol_block)

          options.merge(options_for_domain_activity: options_for_domain_activity.merge(options_from_block), domain_activity: domain_activity) # TODO: we need generic Normalizer logic somewhere
        end
      end # DSL


      # Runtime code uses instance methods from {Config} to retrieve necessary dependencies,
      # nothing else.
      module Runtime
        def normalize_invoke_options(operation, protocol: false, **options)
          invoke_options =
            {protocol: protocol}.
              merge(_invoke_options) # TODO: pass options.

          return invoke_options, options
        end

        # TODO: allow setting {runtime_call} as a "global" via endpoint{}
        def invoke(operation, runtime_call: Trailblazer::Invoke, **options, &matcher_block)
          invoke_options, options = normalize_invoke_options(operation, **options)

          if invoke_options[:protocol]
            action_protocol = _endpoints.fetch(operation.to_s)
          else
            action_protocol = operation
          end

          options_for_block = {
            controller:     self,
            activity:       action_protocol, # TODO: test me for all receiving directives.
            invoke_options: options,
          }

          flow_options_from_controller = _flow_options(**options_for_block)
          ctx           = _options_for_endpoint_ctx(**options_for_block).merge(options)

          default_matcher = _default_matcher_for_endpoint()

          runtime_call.(action_protocol, ctx, default_matcher: default_matcher, matcher_context: self,
             flow_options_from_controller: flow_options_from_controller,
            &matcher_block)
        end
      end


    end # Controller
  end
end
