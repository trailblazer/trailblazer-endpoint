module Trailblazer
  class Endpoint
    class Matcher
      def self.call(outcome, (ctx, kwargs), merge: {}, exec_context:, matcher:)
        block = matcher.merge(merge).fetch(outcome)

        exec_context.instance_exec(ctx, **kwargs, &block)
      end

      def self.Extension
        Activity::TaskWrap::Pipeline.Row("endpoint.run_matcher", method(:run_matcher)) # TODO: I don't like using this super low-level TW interface.
      end

      # TaskWrap extension that's run after the {domain_activity}. This used to sit in the Adapter,
      # but for simplicity reasons we removed Adapter for the evaluation release time.
      def self.run_matcher(wrap_ctx, original_args)
        ctx, flow_options = wrap_ctx[:return_args]

        matcher_value = flow_options[:matcher_value]

        outcome = wrap_ctx[:return_signal].to_h[:semantic]

        # Execute the literal block from the controller action.
        matcher_value.call(outcome, [ctx, ctx.to_h]).inspect # DISCUSS: this shouldn't mutate anything.

        return [wrap_ctx, original_args]
      end

      # Object that collects user blocks to handle various outcomes.
      class DSL < Struct.new(:blocks)
        def initialize(*)
          self.blocks = {}
        end

        def method_missing(method_name, &block)
          blocks[method_name] = block
          self
        end

        def to_h
          blocks
        end
      end

      # This is the runtime interface that executes the respective matcher for the
      # result outcome.
      class Value
        def initialize(matcher, dsl, exec_context)
          @matcher      = matcher
          @dsl_merge    = dsl.to_h
          @exec_context = exec_context
        end

        def call(outcome, args, **kwargs)
          Matcher.(outcome, args, matcher: @matcher, merge: @dsl_merge, exec_context: @exec_context)
        end
      end
    end
  end
end
