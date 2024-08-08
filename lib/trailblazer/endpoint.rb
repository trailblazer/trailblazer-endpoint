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

      protocol_with_domain_activity = Protocol.build(protocol: protocol, domain_activity: domain_activity, options_for_domain_activity: options_for_domain_activity)
      # puts Trailblazer::Developer.render(protocol_with_domain_activity)
    end
  end
end

require "trailblazer/endpoint/protocol"
require "trailblazer/endpoint/matcher"
require "trailblazer/endpoint/runtime"
require "trailblazer/endpoint/controller"

