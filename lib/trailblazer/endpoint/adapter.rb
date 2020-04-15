module Trailblazer
  class Endpoint
    module Adapter
      # Basic endpoint adapter for a HTTP document API.
      # As always: "work in progress" ;)
      #
      # {End.fail_fast} currently implies a 4xx-able error.
      class API < Trailblazer::Activity::FastTrack
        _404_path = ->(*) { step :_404_status }
        _401_path = ->(*) { step :_401_status }
        _403_path = ->(*) { step :_403_status }

        step Subprocess(EndpointTest::PrototypeEndpoint),
            Output(:not_authorized)     => Path(track_color: :_403, connect_to: Id(:render_protocol_failure_config), &_403_path),
            Output(:not_found)          => Path(track_color: :_404, connect_to: Id(:protocol_failure), &_404_path),
            Output(:not_authenticated)  => Path(track_color: :_401, connect_to: Id(:render_protocol_failure_config), &_401_path)       # head(401), representer: Representer::Error, message: no token

            # failure is automatically wired to failure, being an "application error" vs. a "protocol error (auth, etc)"


            fail :failure_render_config
            fail :failure_config_status
            fail :render_failure

            step :success_render_config
            step :success_render_status
            step :render_success


          # :protocol_join is a :failure_config alias
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

        def render_success(ctx, **)
          ctx[:json] = %{#{ctx[:representer]}.new(#{ctx[:model]})}
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

        def render_failure(*args)
          render_success(*args)
        end
  # how/where would we configure each endpoint? (per action)
    # class Endpoint
    #   representer ...
    #   message ...

        def _401_status(ctx, **)
          ctx[:status] = 401
          # ctx[:model] = Struct.new(:error_message).new("No token")
        end

        def _404_status(ctx, **)
          ctx[:status] = 404
        end

        def _403_status(ctx, **)
          ctx[:status] = 403
        end

        # def exec_success(ctx, success_block:, **)
        #   success_block.call(ctx, **ctx.to_hash) # DISCUSS: use Nested(dynamic) ?
        # end
      end
    end
  end
end
