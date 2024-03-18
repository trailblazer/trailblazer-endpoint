module Trailblazer
  class Endpoint
    class Matcher < Struct.new(:blocks)
      def initialize(**blocks)
        super(blocks)
      end

      def call(outcome, (ctx, kwargs), merge: {}, exec_context:)
        block = blocks.merge(merge).fetch(outcome)

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

      class Value
        def initialize(matcher, dsl, exec_context)
          @matcher      = matcher
          @dsl_merge    = dsl.to_h
          @exec_context = exec_context
        end

        def call(outcome, args, **kwargs)
          @matcher.(outcome, args, merge: @dsl_merge, exec_context: @exec_context)
        end
      end
    end
  end
end
