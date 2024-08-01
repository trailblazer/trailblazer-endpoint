module Trailblazer
  class Endpoint
    # Create an {Endpoint} class with the provided adapter and protocol.
    # This builder also sets up taskWrap filters around the {domain_activity} execution.
    def self.build(protocol:, domain_activity:, options_for_domain_activity: {}, **) # FIXME: no **
      # special considerations around the {domain_activity} and its taskWrap:
      #
      #  1. domain_ctx_filter (e.g. to filter {current_user})
      #  2. :input (scope {:domain_ctx})
      #  3. call (domain_activity)
      #  4. :output
      #  5. save return signal

      # DISCUSS: extract this high level DSL logic



      protocol_with_domain_activity = Protocol.build(protocol: protocol, domain_activity: domain_activity, options_for_domain_activity: options_for_domain_activity)

      puts Trailblazer::Developer.render(protocol_with_domain_activity)

      return protocol_with_domain_activity

      # FIXME: test {:adapter}
      # FIXME: make this optional to reduce complexity.
      adapter_for_action = adapter.build(protocol_with_domain_activity)
      # Class.new(adapter) do
      #   step(Subprocess(protocol_with_domain_activity), {inherit: true, id: :protocol, replace: :protocol})
      # end
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
