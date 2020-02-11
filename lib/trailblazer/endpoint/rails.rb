module Trailblazer::Endpoint::Handlers
  # Generic matcher handlers for a Rails API backend.
  #
  # Note that the path mechanics are experimental. PLEASE LET US KNOW WHAT
  # YOU NEED/HOW YOU DID IT: https://gitter.im/trailblazer/chat
  class Rails
    def initialize(controller, options)
      @controller = controller
      @path       = options[:path]
    end

    attr_reader :controller

    def call
      ->(m) do
        m.not_found { |res| render_json_error(res, 404) }
        m.unauthenticated { |res| render_json_error(res, 401) }
        m.unauthorized { |res| render_json_error(res, 403) }
        m.invalid_params { |res| render_json_error(res, 422) }
      end
    end

    private

    def render_json_error(ctx, status)
      err_msg = ctx['trailblazer-endpoint.error'] || default_for(status)
      controller.render(json: err_msg, status: status)
    end

    def default_for(status_code)
      default_msg = {
        401 => 'Unauthorized.',
        403 => 'Forbidden.',
        404 => 'Resource not found.',
        422 => 'Unprocessable entity.'
      }

      default_msg[status_code]
    end
  end
end
