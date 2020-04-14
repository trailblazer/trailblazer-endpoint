module Trailblazer
  class Endpoint
    module Adapter
      # Basic endpoint adapter for a HTTP document API.
      # As always: "work in progress" ;)
      class API < Trailblazer::Activity::FastTrack
        _404_path = ->(*) { step :_404_status }
        _401_path = ->(*) { step :_401_ }

        step Subprocess(EndpointTest::PrototypeEndpoint),
            Output(:not_authorized)     => Id(:render_policy_breach),    # head(403), representer: Representer::Error, message: wrong permissions
            Output(:not_found)          => Path(track_color: :_404, connect_to: Id(:protocol_failure), &_404_path),
            Output(:not_authenticated)  => Path(track_color: :_401, connect_to: Id(:render_protocol_failure), &_401_path)       # head(401), representer: Representer::Error, message: no token

            # failure is automatically wired to failure, being an "application error" vs. a "protocol error (auth, etc)"

            step :config_success
            fail :config_failure
            fail :config_failure_status

            step :render_success
            fail :render_failure


          # :protocol_join is a :config_failure alias
          step :render_protocol_failure, magnetic_to: nil, Output(:success) => Path(connect_to: Id("End.fail_fast")) do
            step :protocol_failure
          end

        def config_success(ctx, **)
          ctx[:status] = 200
          ctx[:representer] = "DiagramRepresenter"
        end

        def render_success(ctx, **)
          ctx[:json] = %{#{ctx[:representer]}.new(#{ctx[:model]})}
        end

        def config_failure(ctx, **)
          ctx[:representer] = "ErrRepres"
          # ctx[:status] = raise # DISCUSS: where and HOW do we find out what is wrong? e.g. 422 Unprocessable Entity
        end

        def config_failure_status(ctx, **)
          # DISCUSS: this is a bit like "success?" or a matcher.
          if ctx[:validate] === false
            ctx[:status] = 422
          else
            ctx[:status] = 200 # DISCUSS: this is the usual return code for application/domain errors, I guess?
          end
        end

        def protocol_failure(*args)
          #config_failure(*args)
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

        def _401_(ctx, **)
          ctx[:status] = 401
          ctx[:representer] = "ErrorRepresenter"
          ctx[:model] = Struct.new(:error_message).new("No token")
        end

        def _404_status(ctx, **)
          ctx[:status] = 404
        end

        # def exec_success(ctx, success_block:, **)
        #   success_block.call(ctx, **ctx.to_hash) # DISCUSS: use Nested(dynamic) ?
        # end
      end
    end
  end
end
