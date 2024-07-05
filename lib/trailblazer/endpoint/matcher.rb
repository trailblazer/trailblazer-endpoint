module Trailblazer
  class Endpoint
    class Matcher
      def self.call(outcome, (ctx, kwargs), merge: {}, exec_context:, matcher:)
        block = matcher.merge(merge).fetch(outcome)

        exec_context.instance_exec(ctx, **kwargs, &block)
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
