module Trailblazer
  class Endpoint
    module Runtime
      module_function

      # We run the Adapter here, which in turn will run your business operation, then the matcher
      # or whatever you have configured.
      #
      # This method is basically replacing {Operation.call_with_public_interface}, from a logic perspective.
      def call(activity, ctx, flow_options: {}, extensions: [], invoke_method: Trailblazer::Activity::TaskWrap.method(:invoke), &block) # TODO: test {flow_options} # TODO: test {invoke_method}
        # Instead of creating the {ctx} manually, use an In() filter for the outermost activity.
        # Currently, the interface is a bit awkward, but we're going to fix this.
        in_extension = Class.new(Activity::Railway) do
          step :a, In() => ->(ctx, **) { ctx } # wrap hash into Trailblazer::Context, super awkward
        end.to_h[:config][:wrap_static].values.first.to_a[0..1] # no Out() extension. FIXME: maybe I/O should have some semi-private API for that?

        pipeline = Activity::TaskWrap::Pipeline.new(in_extension + extensions) # DISCUSS: how and where to run the matcher, especially with an protocol.

        container_activity = Activity::TaskWrap.container_activity_for(activity, wrap_static: pipeline)

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
        )
      end

# FIXME: test me:
      module Matcher
        # Adds the matcher logic to invoking an activity via an "endpoint" (actually, this is not related to endpoints at all).
        def self.call(activity, ctx, flow_options: {}, matcher_context:, default_matcher:, matcher_extension: Endpoint::Matcher.Extension(), &block)
          matcher = Trailblazer::Endpoint::Matcher::DSL.new.instance_exec(&block)

          matcher_value = Trailblazer::Endpoint::Matcher::Value.new(default_matcher, matcher, matcher_context)

          flow_options = flow_options.merge(matcher_value: matcher_value) # matchers will be executed in Adapter's taskWrap.

          Runtime.(activity, ctx, flow_options: flow_options, extensions: [matcher_extension])
        end
      end
    end # Runtime
  end
end
