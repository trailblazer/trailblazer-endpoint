require "trailblazer/endpoint/controller"

class ApplicationController < ActionController::Base
  include Trailblazer::Endpoint::Controller.module

  module Endpoint
    class Protocol < Trailblazer::Endpoint::Protocol::Operation
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
        fast_track_to_railway: true, # per default, wire fast track outputs to success/failure.
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
