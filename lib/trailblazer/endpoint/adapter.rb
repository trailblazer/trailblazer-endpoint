module Trailblazer
  class Endpoint

    # The idea is to use the CreatePrototypeProtocol's outputs as some kind of protocol, outcomes that need special handling
    # can be wired here, or merged into one (e.g. 401 and failure is failure).
    # I am writing this class in the deep forests of the Algarve, hiding from the GNR.
    # class Adapter < Trailblazer::Activity::FastTrack # TODO: naming. it's after the "application logic", more like Controller
 # Currently reusing End.fail_fast as a "something went wrong, but it wasn't a real application error!"


    module Adapter
      class Web <Trailblazer::Activity::FastTrack
        _404_path = ->(*) { step :_404_status }
        _401_path = ->(*) { step :_401_status }
        _403_path = ->(*) { step :_403_status }
        # _422_path = ->(*) { step :_422_status } # TODO: this is currently represented by the {failure} track.

        step Subprocess(Protocol), # this will get replaced
          id: :protocol,
          Output(:not_authorized)     => Path(track_color: :not_authorized, connect_to: Id(:protocol_failure), &_403_path),
          Output(:not_found)          => Path(track_color: :not_found, connect_to: Id(:protocol_failure), &_404_path),
          Output(:not_authenticated)  => Path(track_color: :not_authenticated, connect_to: Id(:protocol_failure), &_401_path),
          Output(:invalid_data)       => Track(:failure) # application error, since it's usually a failed validation.

        step :protocol_failure, magnetic_to: nil, Output(:success) => Track(:fail_fast), Output(:failure) => Track(:fail_fast)

        def protocol_failure(ctx, **)
          true
        end


# FIXME:::::::
        def _401_status(ctx, **)
          ctx[:status] = 401
        end

        def _404_status(ctx, **)
          ctx[:status] = 404
        end

        def _403_status(ctx, **)
          ctx[:status] = 403
        end
      end

      class API < Web
        step :_200_status, after: :protocol

        def _200_status(ctx, success_status: 200, **)
          ctx[:status] = success_status
        end

        fail :_422_status, before: "End.failure"

        def _422_status(ctx, **)
          ctx[:status] = 422
        end


        def self.insert_error_handler_steps(adapter)
          adapter = Class.new(adapter) do
            step :handle_not_authenticated, magnetic_to: :not_authenticated, Output(:success) => Track(:not_authenticated), Output(:failure) => Track(:not_authenticated), before: :_401_status
            step :handle_not_authorized, magnetic_to: :not_authorized, Output(:success) => Track(:not_authorized), Output(:failure) => Track(:not_authorized), before: :_403_status
            # step :handle_not_found, magnetic_to: :not_found, Output(:success) => Track(:not_found), Output(:failure) => Track(:not_found)
            fail :handle_invalid_data
          end
        end

        class Errors < Struct.new(:message, :errors) # FIXME: extract
          module Handlers
            def handle_not_authenticated(ctx, errors:, **)
              errors.message = "Authentication credentials were not provided or are invalid."
            end

            def handle_not_authorized(ctx, errors:, **)
              errors.message = "Action not allowed due to a policy setting."
            end

            def handle_invalid_data(ctx, errors:, **)
              errors.message = "The submitted data is invalid."
            end
          end
        end
      end # API

    end
  end
end
