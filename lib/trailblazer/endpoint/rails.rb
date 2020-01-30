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
        m.not_found { |res| controller.render json: 'Resource not found.', status: 404 }
        m.unauthenticated { |res| controller.render json: 'Unauthorized.', status: 401 }
        m.unauthorized { |res| controller.render json: 'Forbidden.', status: 403 }
        m.invalid_params { |res| controller.render json: 'Unprocessable entity.', status: 422 }
      end
    end
  end
end
