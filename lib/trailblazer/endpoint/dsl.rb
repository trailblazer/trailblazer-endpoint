module Trailblazer
  class Endpoint
    module DSL
      # Run before the endpoint is invoked. This collects the blocks from the controller.
      class Runtime < Struct.new(:options, :success_block, :failure_block, :protocol_failure_block)

        def failure(&block)
          self.failure_block = block
          self
        end

        alias_method :Or, :failure

        def protocol_failure(&block)
          self.protocol_failure_block = block
          self
        end

        # #call
        def to_args(default_block_options)
          return options, default_block_options.merge(success_block: success_block, failure_block: failure_block, protocol_failure_block: protocol_failure_block)
        end
      end
    end
  end
end
