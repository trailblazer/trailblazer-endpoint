require "trailblazer/endpoint/controller"

#:application-controller
class ApplicationController < ActionController::Base
  #~include
  include Trailblazer::Endpoint::Controller.module
  #~include end
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
    ctx do |controller:, **| # this block is executed in controller instance context.
      {
        params:       controller.params,
        current_user: controller.current_user,
      }
    end
    #~ctx end

    #~flow_options
    flow_options do |controller:, activity:, **|
      {
        context_options: {
          aliases: {"contract.default": :contract},
          container_class: Trailblazer::Context::Container::WithAliases,
        }
      }
    end
    #~flow_options end

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
