module Trailblazer
  class Endpoint
    module Runtime
      module_function

      # We run the Adapter here, which in turn will run your business operation, then the matcher
      # or whatever you have configured.
      def call(ctx, adapter:, flow_options: {}, matcher_context:, default_matcher:, &block) # TODO: test {flow_options}
        matcher = Trailblazer::Endpoint::Matcher::DSL.new.instance_exec(&block)

        matcher_value = Trailblazer::Endpoint::Matcher::Value.new(default_matcher, matcher, matcher_context)

        # Instead of creating the {ctx} manually, use an In() filter for the outermost activity.
        # Currently, the interface is a bit awkward, but we're going to fix this.
        in_extension = Class.new(Activity::Railway) do
          step :a, In() => ->(ctx, **) { ctx } # wrap hash into Trailblazer::Context, super awkward
        end.to_h[:config][:wrap_static].values.first.to_a[0..1] # no Out() extension. FIXME: maybe I/O should have some semi-private API for that?

        pipeline = Activity::TaskWrap::Pipeline.new(in_extension)

        container_activity = Activity::TaskWrap.container_activity_for(adapter, wrap_static: pipeline)

        # Trailblazer::Activity::TaskWrap.invoke( # FIXME: run Advance using this, not its own wtf?/call invocation.
        Trailblazer::Developer.wtf?( # FIXME: run Advance using this, not its own wtf?/call invocation.
          adapter,
          [
            ctx,
            flow_options.merge(matcher_value: matcher_value) # matchers will be executed in Adapter's taskWrap.
          ],

          container_activity: container_activity,
          exec_context: self,
          # wrap_runtime: {adapter => ->(*) { snippet }} # TODO: use wrap_runtime once https://github.com/trailblazer/trailblazer-developer/issues/46 is fixed.
        )
      end
    end # Runtime
  end
end
