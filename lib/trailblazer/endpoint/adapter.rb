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
          Output(:not_authorized)     => Path(track_color: :_403, connect_to: Id(:protocol_failure), &_403_path),
          Output(:not_found)          => Path(track_color: :_404, connect_to: Id(:protocol_failure), &_404_path),
          Output(:not_authenticated)  => Path(track_color: :_401, connect_to: Id(:protocol_failure), &_401_path),
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

      # Basic endpoint adapter for a HTTP document API.
      # As always: "work in progress" ;)
      #
      # {End.fail_fast} currently implies a 4xx-able error.
      class API < Trailblazer::Activity::FastTrack
        _404_path = ->(*) { step :_404_status }
        _401_path = ->(*) { step :_401_status; step :_401_error_message }
        _403_path = ->(*) { step :_403_status }
        # _422_path = ->(*) { step :_422_status } # TODO: this is currently represented by the {failure} track.

        # The API Adapter automatically wires well-defined outputs for you to well-defined paths. :)
# FIXME

        step Subprocess(Protocol), # this will get replaced
          id: :protocol,
          Output(:not_authorized)     => Path(track_color: :_403, connect_to: Id(:render_protocol_failure_config), &_403_path),
          Output(:not_found)          => Path(track_color: :_404, connect_to: Id(:protocol_failure), &_404_path),
          Output(:not_authenticated)  => Path(track_color: :_401, connect_to: Id(:render_protocol_failure_config), &_401_path),       # head(401), representer: Representer::Error, message: no token
          Output(:invalid_data)       => Track(:failure) # application error, since it's usually a failed validation.

            # extensions: [Trailblazer::Activity::TaskWrap::Extension(merge: TERMINUS_HANDLER)]
            # failure is automatically wired to failure, being an "application error" vs. a "protocol error (auth, etc)"


            fail :failure_render_config
            fail :failure_config_status
            fail :render_failure

            step :success_render_config
            step :success_render_status
            step :render_success


          # DISCUSS: "protocol failure" and "application failure" should be the same path, probably?
          step :render_protocol_failure_config, magnetic_to: nil, Output(:success) => Path(connect_to: Id("End.fail_fast")) do
            step :render_protocol_failure
            step :protocol_failure
          end

=begin
          render_protocol_failure_config # representer
          render_protocol_failure        # Representer.new
          protocol_failure               # true
=end

        def success_render_status(ctx, **)
          ctx[:status] = 200
        end

        def success_render_config(ctx, representer:, **)
          true
        end

        def render_protocol_failure_config(*args)
          failure_render_config(*args)
        end

# ROAR
        def render_success(ctx, representer:, domain_ctx:, **)
          model = domain_ctx[:model]
          ctx[:json] = representer.new(model).to_json # FIXME: use the same as render_failure.
        end

        def failure_render_config(ctx, error_representer:, **)
          ctx[:representer] = error_representer
        end

        def failure_config_status(ctx, **)
          ctx[:status] = 422
        end

        def protocol_failure(*args)
          #failure_config(*args)
          true
        end
        def render_protocol_failure(*args)
          render_failure(*args)
        end

      # ROAR
        def render_failure(ctx, error_representer:, errors:, **)
          # render_success(*args)
          ctx[:json] = error_representer.new(errors).to_json
      end
  # how/where would we configure each endpoint? (per action)
    # class Endpoint
    #   representer ...
    #   message ...

        def _401_status(ctx, **)
          ctx[:status] = 401
        end

        def _404_status(ctx, **)
          ctx[:status] = 404
        end

        def _403_status(ctx, **)
          ctx[:status] = 403
        end

        def _401_error_message(ctx, **)
          ctx[:error_message] = "Authentication credentials were not provided or invalid."
        end

        # def exec_success(ctx, success_block:, **)
        #   success_block.call(ctx, **ctx.to_hash) # DISCUSS: use Nested(dynamic) ?
        # end
      end
    end
  end
end
