require "trailblazer/activity/dsl/linear"

# TODO: 2BRM? It's probably harder to explain what goes on here than to just let people write their own Protocol?

module Trailblazer
  class Endpoint
    # The {Protocol} implements auth*, and calls the domain OP/WF.
    # You still have to implement handlers (like {#authorize} and {#handle_not_authorized}) yourself. This might change soon.
    #
    # Protocol must provide all termini for the Adapter (401,403 and 404 in particular), even if the ran op/workflow doesn't have it.
    #   Still thinking about how to do that best.

    # Termini and their "pendants" in HTTP, which is unrelated to protocol!! Protocol is application-focused and doesn't know about HTTP.
    #   failure: 411
    #   success: 200
    #   not_found: 404
    #   not_authenticated: 401
    #   not_authorized: 403
    class Protocol < Trailblazer::Activity::Railway

      # extensions_options = {
      #   Extension() => Trailblazer::Activity::TaskWrap::Extension::WrapStatic(
      #     [method(:run_matcher), id: "endpoint.run_matcher", append: "task_wrap.call_task"],
      #   ),
      # }

      # @private
      def self.build(protocol:, domain_activity:, options_for_domain_activity:)
        Class.new(protocol) do
          step(Subprocess(domain_activity, strict: true), {inherit: true, replace: :domain_activity,}.
            # merge(extensions_options).
            merge(options_for_domain_activity)
          )
        end
      end

      class Noop < Trailblazer::Activity::Railway
      end

      def self._Path(semantic:, &block) # DISCUSS: the problem with Path currently is https://github.com/trailblazer/trailblazer-activity-dsl-linear/issues/27
        Path(track_color: semantic, terminus: semantic, &block)
      end

      step :authenticate, Output(:failure) => _Path(semantic: :not_authenticated) do
          # step :handle_not_authenticated
      end

      step :policy, Output(:failure) => _Path(semantic: :not_authorized) do # user from cookie, etc
        # step :handle_not_authorized
      end

      # Here, we test a domain OP with ADDITIONAL explicit ends that get wired to the Adapter (vaidation_error => failure).
      # We still need to test the other way round: wiring a "normal" failure to, say, not_found, by inspecting the ctx.
      step Subprocess(Noop), id: :domain_activity



      # add the {End.not_found} terminus to this Protocol. I'm not sure that's the final style, but since a {Protocol} needs to provide all
      # termini for the Adapter this is the only way to get it working right now.
      terminus :not_found
      terminus :invalid_data

      class Operation < Protocol
        terminus :fail_fast
        terminus :pass_fast
      end
    end # Protocol
  end
end
