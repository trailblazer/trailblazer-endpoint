module Trailblazer
  class Endpoint
    # Create an {Endpoint} class with the provided adapter and protocol.
    # This builder also sets up taskWrap filters around the {domain_activity} execution.
    def self.build(adapter:, protocol:, domain_activity:, protocol_block: ->(*) { Hash.new })
      # special considerations around the {domain_activity} and its taskWrap:
      #
      #  1. domain_ctx_filter (e.g. to filter {current_user})
      #  2. :input (scope {:domain_ctx})
      #  3. call (domain_activity)
      #  4. :output
      #  5. save return signal

      protocol_with_domain_activity = build_protocol(protocol: protocol, domain_activity: domain_activity, protocol_block: protocol_block)

      # puts Trailblazer::Developer.render(app_protocol)

      adapter_for_action = Adapter.build(protocol_with_domain_activity)
      # Class.new(adapter) do
      #   step(Subprocess(protocol_with_domain_activity), {inherit: true, id: :protocol, replace: :protocol})
      # end
    end

    # @private
    # TODO: move to Protocol.
    def self.build_protocol(protocol:, domain_activity:, protocol_block:)
      Class.new(protocol) do
        step(Subprocess(domain_activity), {inherit: true, replace: :domain_activity,}.
          # merge(extensions_options).
          merge(instance_exec(&protocol_block)) # the block is evaluated in the {Protocol} context.
        )
      end
    end
  end
end

require "trailblazer/endpoint/protocol"
require "trailblazer/endpoint/adapter"
require "trailblazer/endpoint/matcher"
require "trailblazer/endpoint/runtime"
# require "trailblazer/endpoint/dsl"
require "trailblazer/endpoint/controller"
# require "trailblazer/endpoint/options"
# require "trailblazer/endpoint/protocol/controller"
# require "trailblazer/endpoint/protocol/find_process_model"
# require "trailblazer/endpoint/protocol/cipher"
