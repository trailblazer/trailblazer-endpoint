require "trailblazer/endpoint/controller"

#:application-controller-include
#:application-controller
class ApplicationController < ActionController::Base
  include Trailblazer::Endpoint::Controller.module
#:application-controller-include end
  #~config

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

  #~config end
  #~endpoint
  endpoint do
    #~config
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

    #~config end
    default_matcher do
      {

        failure: ->(ctx, **) { head 401 }, # handles {failure} outcome.
        not_found: ->(ctx, params:, **) do
          render html: "ID #{params[:id]} not found.",
                 status: 404
        end
      }
    end
  end
  #~endpoint end
end
#:application-controller end
