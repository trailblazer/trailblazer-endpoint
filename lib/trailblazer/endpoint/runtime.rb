module Trailblazer
  class Endpoint
    module Runtime
      def self.module!(target, canonical_invoke_name: :__,  &arguments_block)
        target.include Trailblazer::Endpoint::Runtime::Canonical # #__

        # DISCUSS: store arguments_block in a class instance variable and refrain from using {define_method}?

        target.define_method(canonical_invoke_name) do |*args, **kws, &block|
          Runtime::Canonical.__(*args, my_dynamic_arguments: arguments_block, **kws, &block)
        end

        # class_eval do
        #   arguments_block = arguments_block

        #   def __(*args, **kws, &block)
        #     super(*args, my_dynamic_arguments: arguments_block, **kws, &block)
        #   end
        # end
      end

      # This module implements the end user's top level entry point for running activities.
      # By "overriding" **kws they can inject any {flow_options} or other {Runtime.call} options needed.
      # See runtime_test.rb.
      module TopLevel
        # TODO: we should also aggregate flow_options here?
        # TODO: {:invoke_method} and {:present_options}.
        # TODO: allow different Runtime::Matcher etc.
        def __(activity, options, **kws, &block)
          signal, (ctx, _) = Trailblazer::Endpoint::Runtime.(activity, options, **kws, &block)

          return signal, ctx # DISCUSS: should we provide a Result object here?
        end

        def __?(*args, &block) # TODO: move this to endpoint.
          __(*args, invoke_method: Trailblazer::Developer::Wtf.method(:invoke), &block)
        end
      end

      # Currently, "Canonical" implies that some options-compiler is executed to
      # aggregate flow_options, Runtime.call options like :invoke_method, circuit_options,
      # etc.
      module Canonical # DISCUSS: remove TopLevel?
        module_function

        def __(activity, options, my_dynamic_arguments:, **kws, &block)
          Trailblazer::Endpoint::Runtime.(
            activity, options,
            **my_dynamic_arguments.(activity, options, **kws), # represents {:invoke_method} and {:present_options}
            **kws,
            &block
          )
        end

        def __?(activity, options, my_dynamic_arguments:, **kws, &block)
          Trailblazer::Endpoint::Runtime.(
            activity, options,
            **my_dynamic_arguments.(activity, options, **kws), # represents {:invoke_method} and {:present_options}
            invoke_method: Trailblazer::Developer::Wtf.method(:invoke),
            **kws,
            &block
          )
        end
      end

      module_function

      # @public
      # Top-level entry point.
      def call(activity, ctx, default_matcher: {}, matcher_context: self, **options, &block)
        return Invoke.(activity, ctx, **options) unless block_given?

        Matcher.(activity, ctx, default_matcher: default_matcher, matcher_context: matcher_context, **options, &block)
      end

      module Invoke
        module_function

        # We run the Adapter here, which in turn will run your business operation, then the matcher
        # or whatever you have configured.
        #
        # This method is basically replacing {Operation.call_with_public_interface}, from a logic perspective.
        #
        # NOTE: {:invoke_method} is *not* activity API, that's us here using it.
        def call(activity, ctx, flow_options: {}, extensions: [], invoke_method: Trailblazer::Activity::TaskWrap.method(:invoke), circuit_options: {}, **, &block) # TODO: test {flow_options} # TODO: test {invoke_method}
          # Instead of creating the {ctx} manually, use an In() filter for the outermost activity.
          # Currently, the interface is a bit awkward, but we're going to fix this.
          in_extension = Class.new(Activity::Railway) do
            step :a, In() => ->(ctx, **) { ctx } # wrap hash into Trailblazer::Context, super awkward
          end.to_h[:config][:wrap_static].values.first.to_a[0..1] # no Out() extension. FIXME: maybe I/O should have some semi-private API for that?

          pipeline = Activity::TaskWrap::Pipeline.new(in_extension + extensions) # DISCUSS: how and where to run the matcher, especially with an protocol.

          container_activity = Activity::TaskWrap.container_activity_for(activity, wrap_static: pipeline)

# invoke_method = Trailblazer::Developer::Wtf.method(:invoke)
          invoke_method.( # FIXME: run Advance using this, not its own wtf?/call invocation.
          # Trailblazer::Developer.wtf?( # FIXME: run Advance using this, not its own wtf?/call invocation.
            activity,
            [
              ctx,
              flow_options
            ],

            container_activity: container_activity,
            exec_context: self,
            # wrap_runtime: {activity => ->(*) { snippet }} # TODO: use wrap_runtime once https://github.com/trailblazer/trailblazer-developer/issues/46 is fixed.
            **circuit_options
          )
        end

      end

      module Matcher
        module_function

        # Adds the matcher logic to invoking an activity via an "endpoint" (actually, this is not related to endpoints at all).
        def call(activity, ctx, flow_options: {}, matcher_context:, default_matcher:, matcher_extension: Endpoint::Matcher.Extension(), **kws, &block)
          matcher = Trailblazer::Endpoint::Matcher::DSL.new.instance_exec(&block)

          matcher_value = Trailblazer::Endpoint::Matcher::Value.new(default_matcher, matcher, matcher_context)

          flow_options = flow_options.merge(matcher_value: matcher_value) # matchers will be executed in Adapter's taskWrap.

          Invoke.(activity, ctx, flow_options: flow_options, extensions: [matcher_extension], **kws) # TODO: we *might* be overriding {:extensions} here.
        end
      end
    end # Runtime
  end
end
