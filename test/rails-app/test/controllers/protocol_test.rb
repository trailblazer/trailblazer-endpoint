require "test_helper"

class ProtocolTest < ActionDispatch::IntegrationTest
  class AuthorizeFromJWT
    def self.call(request)
      "user XXX"
    end
  end

  module A
    Memo = Module.new

    class ApplicationController < ActionController::Base
      include Trailblazer::Endpoint::Controller.module
    end

    module Memo::Operation
      class Create < Trailblazer::Operation
        step :validate, fail_fast: true
        step :model

        def validate(ctx, params:, **)
          params[:memo]
        end

        def model(ctx, params:, **)
          ctx[:model] = ::Memo.create(**params[:memo].permit!)
        end
      end
    end

    #:endpoint-controller
    class MemosController < ApplicationController
      #:protocol
      class Protocol < Trailblazer::Activity::Railway # two termini.
        step :authenticate              # our imaginary logic to find {current_user}.
        step nil, id: :domain_activity  # {Memo::Operation::Create} gets placed here.

        def authenticate(ctx, request:, **)
          ctx[:current_user] = AuthorizeFromJWT.(request)
        end
      end
      #:protocol end

      #~define
      endpoint Memo::Operation::Create, protocol: Protocol # define endpoint.
      #~define end

      # endpoint do
      #   invoke do
      #     {protocol: true}
      #   end
      # end

      #~create
      def create
        invoke Memo::Operation::Create, protocol: true, request: request, params: params do
          success { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          failure { |ctx, params:, **| head 401 }
        end
      end
      #~create end
    end
    #:endpoint-controller end
  end # A

  test "unconfigured ApplicationController" do
  # 201
    post "/po/a", params: {memo: {id: 1, text: "Remember that!"}}
    assert_redirected_to "/memos/1"

  # 401
    post "/po/a", params: {} # fail_fast
    assert_response 401
    assert_equal "", response.body
  end
end

