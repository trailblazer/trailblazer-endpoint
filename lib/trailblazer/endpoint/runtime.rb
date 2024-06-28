module Trailblazer
  class Endpoint
    module Runtime
      module_function

      # We run the Adapter here, which in turn will run your business operation, then the matcher
      # or whatever you have configured.
      def call(ctx, adapter:, flow_options: {}, matcher_context:, default_matcher:, &block) # TODO: test {flow_options}
        matcher = Trailblazer::Endpoint::Matcher::DSL.new.instance_exec(&block)

        matcher_value = Trailblazer::Endpoint::Matcher::Value.new(default_matcher, matcher, matcher_context)

        Trailblazer::Developer.wtf?( # FIXME: run Advance using this, not its own wtf?/call invocation.
          adapter,
          [
            ctx,
            flow_options.merge(matcher_value: matcher_value) # matchers will be executed in Adapter's taskWrap.
          ]
        )
      end
    end # Runtime
  end
end
