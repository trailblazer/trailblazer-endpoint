require "test_helper"

class ProtocolTest < ActionDispatch::IntegrationTest
  class AuthorizeFromJWT
    def self.call(request)
      "user XXX"
    end
  end

  class ApplicationController < ActionController::Base
    include Trailblazer::Endpoint::Controller.module
  end

  module A
    Memo = Module.new

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

  module B
    Memo = A::Memo
    Protocol = A::MemosController::Protocol

    #:controller-options
    class MemosController < ApplicationController
      #~endpoint
      endpoint do
        options do
          {
            protocol: Protocol,
          }
        end
      end
      #~endpoint end
      #~define
      endpoint Memo::Operation::Create # no :protocol needed!
      #~define end

      #~create
      def create
        invoke Memo::Operation::Create, protocol: true, request: request, params: params do
          success { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          failure { |ctx, params:, **| head 401 }
        end
      end
      #~create end
    end
    #:controller-options end
  end

  test "{endpoint.options} defines {:protocol}" do
  # 201
    post "/po/b", params: {memo: {id: 1, text: "Remember that!"}}
    assert_redirected_to "/memos/1"

  # 401
    post "/po/b", params: {} # fail_fast
    assert_response 401
    assert_equal "", response.body
  end

  module C
    # Memo = A::Memo
    Protocol = A::MemosController::Protocol

    module Memo
      module Operation
        class Update < Trailblazer::Operation
          step :model
          step :validate, pass_fast: true, fail_fast: true
          step :dont      # should never be executed.
          fail :dont_fail # should never be executed.

          def validate(ctx, params:, **)
            params[:validate] == "true"
          end

          def model(ctx, **)
            ctx[:model] = Struct.new(:id).new(1)
          end
        end
      end
    end

    #:controller-fast-track
    class MemosController < ApplicationController
      #~endpoint
      endpoint do
        options do
          {
            #~skip
            protocol: Protocol,
            #~skip end
            fast_track_to_railway: true,
          }
        end
      end
      #~endpoint end
      #~define
      endpoint Memo::Operation::Update
      #~define end

      #~create
      def create
        invoke Memo::Operation::Update, protocol: true, request: request, params: params do
          success { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          failure { |ctx, params:, **| head 401 }
        end
      end
      #~create end
    end
    #:controller-fast-track end
  end

  test "there are only pass and fail termini" do
  # 201
    post "/po/c", params: {validate: true}
    assert_redirected_to "/memos/1"

  # 401
    post "/po/c", params: {validate: false}
    assert_response 401
    assert_equal "", response.body
  end

  # override {:fast_track_to_railway} with {endpoint Update}.
  module D
    Memo = C::Memo
    class Protocol < Trailblazer::Activity::FastTrack
      step :authenticate              # our imaginary logic to find {current_user}.
      step nil, id: :domain_activity  # {Memo::Operation::Create} gets placed here.

      def authenticate(ctx, request:, **)
        ctx[:current_user] = AuthorizeFromJWT.(request)
      end
    end

    #:controller-fast-track-false
    class MemosController < ApplicationController
      endpoint do
        options do
          {
            protocol: Protocol,
            fast_track_to_railway: true,
          }
        end
      end
      #~define
      endpoint Memo::Operation::Update,
        fast_track_to_railway: false
      #~define end

      def create
        invoke Memo::Operation::Update, protocol: true, request: request, params: params do
          pass_fast { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          fail_fast { |ctx, params:, **| head 401 }
        end
      end
    end
    #:controller-fast-track-false end
  end

  test "there are {pass_fast} and {fail_fast}" do
  # 201
    post "/po/d", params: {validate: true}
    assert_redirected_to "/memos/1"

  # 401
    post "/po/d", params: {validate: false}
    assert_response 401
    assert_equal "", response.body
  end
end

