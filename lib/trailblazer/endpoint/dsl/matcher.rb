module Trailblazer
  class Endpoint
    module DSL
      # Object that collects user blocks to handle various outcomes.
      class Matcher < Struct.new(:options, :blocks)

        def initialize(*)
          self.blocks = {}
        end

        def method_missing(method_name, &block)
          blocks[method_name] = block
          self
        end

        # #call
        def to_h(default_block_options)
          return options, default_block_options.merge(blocks)
        end
      end
    end
  end
end
