module Trailblazer
  class Endpoint
    # The {Protocol} implements auth*, and calls the domain OP/WF.
    # You still have to implement handlers (like {#authorize} and {#handle_not_authorized}) yourself. This might change soon.
    #
    # Protocol must provide all ends for the Adapter (401,403 and 404 in particular), even if the ran op/workflow doesn't have it.
    #   Still thinking about how to do that best.

    # Termini and their "pendants" in HTTP, which is unrelated to protocol!! Protocol is application-focused and doesn't know about HTTP.
    #   failure: 411
    #   success: 200
    #   not_found: 404
    #   not_authenticated: 401
    #   not_authorized: 403
    class Protocol < Trailblazer::Activity::Railway
      class Noop < Trailblazer::Activity::Railway
      end

      class Failure < Trailblazer::Activity::End # DISCUSS: move to Act::Railway?
        # class Authentication < Failure
        # end
      end

      def self._Path(semantic:, &block) # DISCUSS: the problem with Path currently is https://github.com/trailblazer/trailblazer-activity-dsl-linear/issues/27
        Path(track_color: semantic, end_id: "End.#{semantic}", end_task: Failure.new(semantic: semantic), &block)
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
      # FIXME: is this really the only way to add an {End} to all this?
      @state.update_sequence do |sequence:, **|
        sequence = Activity::Path::DSL.append_end(sequence, task: Failure.new(semantic: :not_found), magnetic_to: :not_found, id: "End.not_found")
        sequence = Activity::Path::DSL.append_end(sequence, task: Failure.new(semantic: :invalid_data), magnetic_to: :invalid_data, id: "End.invalid_data")

        recompile_activity!(sequence)

        sequence
      end

      # Best-practices of useful routes and handlers that work with 2.1-OPs.
      class Standard < Protocol
        step :handle_not_authenticated, magnetic_to: :not_authenticated, Output(:success) => Track(:not_authenticated), Output(:failure) => Track(:not_authenticated)#, before: "End.not_authenticated"
        step :handle_not_authorized,    magnetic_to: :not_authorized, Output(:success) => Track(:not_authorized), Output(:failure) => Track(:not_authorized)
        # step :handle_invalid_data,      magnetic_to: :invalid_data, Output(:success) => Track(:invalid_data), Output(:failure) => Track(:invalid_data)


        # TODO: allow translation.
        module Handler
          def handle_not_authorized(ctx, errors:, **)
            errors.message = "Action not allowed due to a policy setting."
          end

          def handle_not_authenticated(ctx, errors:, **)
            errors.message = "Authentication credentials were not provided or are invalid."
          end
        end

        class Termini # FIXME: this means with invalid_data, not_found termini? 2.1?

        end
      end

      module Bridge
        # this "bridge" should be optional for "legacy operations" that don't have explicit ends.
        # we have to inspect the ctx to find out what "really" happened (e.g. model empty ==> 404)
          NotFound      = Class.new(Trailblazer::Activity::Signal)
          NotAuthorized = Class.new(Trailblazer::Activity::Signal)
          NotAuthenticated = Class.new(Trailblazer::Activity::Signal)

        def self.insert(protocol, **)
          Class.new(protocol) do
            fail :success?, after: :domain_activity,
            # FIXME: how to add more signals/outcomes?
            Output(NotFound, :not_found)            => Track(:not_found),

            # FIXME: Track(:not_authorized) is defined before this step, so the Forward search doesn't find it.
            # solution would be to walk down sequence and find the first {:magnetic_to} "not_authorized"
            Output(NotAuthorized, :not_authorized)  => Track(:not_authorized) # FIXME: how to "insert into path"? => Track(:not_authorized) doesn't play!
          end
        end
      end


      module Domain
        # taskWrap step that saves the return signal of the {domain_activity}.
        # The taskWrap step is usually inserted after {task_wrap.output}.
        def self.terminus_handler(wrap_ctx, original_args)

        #      Unrecognized Signal `"bla"` returned from EndpointTest::LegacyCreate. Registered signals are,
        # - #<Trailblazer::Activity::End semantic=:failure>
        # - #<Trailblazer::Activity::End semantic=:success>
        # - #<Trailblazer::Activity::End semantic=:fromail_fast>

        # {:return_args} is the original "endpoint ctx" that was returned from the {:output} filter.
          wrap_ctx[:return_args][0][:domain_activity_return_signal] = wrap_ctx[:return_signal]

          return wrap_ctx, original_args
        end

        def self.extension_for_terminus_handler
          # this is called after {:output}.
          [[Trailblazer::Activity::TaskWrap::Pipeline.method(:insert_after), "task_wrap.call_task", ["endpoint.end_signal", method(:terminus_handler)]]]
        end
      end

    end
  end
end
