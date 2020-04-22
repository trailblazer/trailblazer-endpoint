module Trailblazer
  class Endpoint
    # The {Protocol} implements auth*, and calls the domain OP/WF.
    # You still have to implement handlers (like {#authorize} and {#handle_not_authorized}) yourself. This might change soon.
    #
    class Protocol < Trailblazer::Activity::Railway
      class Noop < Trailblazer::Activity::Railway
      end

      class Failure < Trailblazer::Activity::End # DISCUSS: move to Act::Railway?
        # class Authentication < Failure
        # end
      end

      def self._Path(semantic:, &block)
        Path(track_color: semantic, end_id: "End.#{semantic}", end_task: Failure.new(semantic: semantic), &block)
      end

      # step :authenticate, Output(:failure) => Path(track_color: :not_authenticated,
      #   connect_to: Id(:handle_not_authenticated)) do# user from cookie, etc

      #   step :a
      # end

      # DISCUSS: do we really need those paths here? On the other hand, they basically come "for free".

      # step :authenticate, Output(:failure) => Track(:_not_authenticated)
      step :authenticate, Output(:failure) => _Path(semantic: :not_authenticated) do
          step :handle_not_authenticated
        end

      step :policy, Output(:failure) => _Path(semantic: :not_authorized) do # user from cookie, etc
        step :handle_not_authorized
      end

      # Here, we test a domain OP with ADDITIONAL explicit ends that get wired to the Adapter (vaidation_error => failure).
      # We still need to test the other way round: wiring a "normal" failure to, say, not_found, by inspecting the ctx.
      step Subprocess(Noop), id: :domain_activity
    end
  end
end
