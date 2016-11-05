require "trailblazer/endpoint"

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
        m.not_found       { |result| controller.head 404 }
        m.unauthenticated { |result| controller.head 401 }
        m.present         { |result| controller.render json: result["representer.serializer.class"].new(result['model']), status: 200 }
        m.created         { |result| controller.head 201, location: "#{@path}/#{result["model"].id}" }#, result["representer.serializer.class"].new(result["model"]).to_json
        m.success         { |result| controller.head 200, location: "#{@path}/#{result["model"].id}" }
        m.invalid         { |result| controller.render json: result["representer.errors.class"].new(result['result.contract'].errors), status: 422 }
      end
    end
  end
end
