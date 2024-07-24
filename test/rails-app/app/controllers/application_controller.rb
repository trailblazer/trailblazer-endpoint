require "trailblazer/endpoint/controller"

class ApplicationController < ActionController::Base
  include Trailblazer::Endpoint::Controller.module

  module Endpoint
    class Protocol < Trailblazer::Endpoint::Protocol
      def authenticate(ctx, **)
        true
      end

      def policy(ctx, **)
        true
      end
    end
  end

  endpoint do
    options do
      {
        protocol: Endpoint::Protocol,
        adapter: Trailblazer::Endpoint::Adapter # TODO: make this optional!
      }
    end

    ctx do
      {
        params: params,
      }
    end

    default_matcher do
      {
        failure: ->(ctx, **) { head 401 }
      }
    end
  end
end
