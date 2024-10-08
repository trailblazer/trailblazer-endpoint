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

  def current_user
    "user"
  end

  #~config end
  #~endpoint
  #:endpoint
  endpoint do
    #~config
    #~options
    options do
      {
        #~protocol
        protocol: Endpoint::Protocol,
        #~protocol end
        # connect fast track outputs to success/failure:
        fast_track_to_railway: true,
      }
    end
    #~options end

    #~ctx
    ctx do # this block is executed in controller instance context.
      {
        params: params,
        current_user: current_user,
      }
    end
    #~ctx end

    #~config end
    #~default_matcher
    default_matcher do
      {
        failure: ->(ctx, **) { head 401 }, # handles {failure} outcome.
        not_found: ->(ctx, params:, **) do
          render html: "ID #{params[:id]} not found.", status: 404
        end
      }
    end
    #~default_matcher end
  end
  #:endpoint end
  #~endpoint end
end
#:application-controller end
