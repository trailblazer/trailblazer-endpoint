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
      class MyProtocol < Trailblazer::Activity::Railway # two termini.
        step :authenticate              # our imaginary logic to find {current_user}.
        step nil, id: :domain_activity  # {Memo::Operation::Create} gets placed here.

        def authenticate(ctx, request:, **)
          ctx[:current_user] = AuthorizeFromJWT.(request)
        end
      end
      #:protocol end

      #~define
      endpoint Memo::Operation::Create, protocol: MyProtocol # define endpoint.
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
    MyProtocol = A::MemosController::MyProtocol

    #:controller-options
    class MemosController < ApplicationController
      #~endpoint
      endpoint do
        options do
          {
            protocol: MyProtocol,
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
    MyProtocol = A::MemosController::MyProtocol

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
            protocol: MyProtocol,
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

  # override {:fast_track_to_railway} when defining {endpoint Update}.
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

  # MyProtocol adds {not_found} and other termini.
  module E
    module Memo; end

    module Memo::Operation
      class Create < Trailblazer::Operation
        step :validate
        step :model

        def validate(ctx, params:, **)
          ctx[:contract] = "Yo, contract."

          params[:memo]
        end

        def model(ctx, params:, **)
          ctx[:model] = ::Memo.create(**params[:memo].permit!)
        end
      end

      class Update < Trailblazer::Operation
        terminus :not_found

        step :find_model, Output(:failure) => Track(:not_found)

        def find_model(ctx, **)
          false
        end
      end
    end


    #:protocol-terminus
    class MyProtocol < Trailblazer::Activity::Railway
      # add additional termini.
      terminus :not_found
      terminus :not_authenticated
      terminus :not_authorized

      step :authenticate, Output(:failure) => Track(:not_authenticated)
      step nil, id: :domain_activity  # {Memo::Operation::Create} gets placed here.

      def authenticate(ctx, params:, **)
        #~skip
        params[:authenticate] != "false"
        #~skip end
      end
    end
    #:protocol-terminus end

    #:controller-protocol-block
    # class ApplicationController < ActionController::Base
    #   include Trailblazer::Endpoint::Controller.module

      # endpoint do
      #   #~options
      #   options do
      #     {
      #       protocol: MyProtocol,
      #       # default wiring, applied to all endpoints:
      #       # protocol_block: -> do
      #       #   {Output(:not_found) => End(:not_found)}
      #       # end
      #     }
      #   end
      #   #~options end
      # end
    # end
    #:controller-protocol-block end

    #:handler-controller
    class MemosController < ApplicationController
      PAGE_404 = "404.html"

      #~handler-five
      endpoint Memo::Operation::Create, protocol: MyProtocol

      def create
        invoke Memo::Operation::Create, protocol: true, params: params do
          success   { |ctx, model:, **| redirect_to memo_path(model.id) }
          failure   { |ctx, contract:, **| render partial: "form", object: contract }
          not_authorized { |**| head 403 }
          not_authenticated { |**| head 401 }
          not_found { |ctx, **| render file: PAGE_404, status: :not_found }
        end
      end
      #~handler-five end

    # Update has {not_found} terminus, it's automatically wired.
      #~update
      endpoint Memo::Operation::Update, protocol: MyProtocol
      #~update end

      def update
        invoke Memo::Operation::Update, protocol: true, params: params do
          # success   { |ctx, model:, **| redirect_to memo_path(model.id) }
          # failure   { |ctx, contract:, **| render partial: "form", object: contract }
          # not_authorized { |**| head 403 }
          # not_authenticated { |**| head 401 }
          not_found { |ctx, **| render file: PAGE_404, status: :not_found }
        end
      end
    end
    #:handler-controller end
  end

  test "we cover five termini" do
  # 200
    post "/po/e", params: {memo: {id: 1}}
    assert_redirected_to "/memos/1"

  # failure/invalid
    post "/po/e", params: {}
    assert_response 200
    assert_equal "<form>Yo, contract.</form>\n", response.body

  # not_authenticated
    post "/po/e", params: {authenticate: "false"}
    assert_response 401
    assert_equal "", response.body

  # not_found
    post "/po/e/update", params: {}
    assert_response 404
    assert_equal "Nothing found!\n", response.body
  end

  # Update has {fail_fast} terminus, we need to wire it manually.
  module F
    module Memo; end

    module Memo::Operation
      class Update < Trailblazer::Operation
        step :find_model, fail_fast: true

        def find_model(ctx, **)
          false
        end
      end
    end

    MyProtocol = E::MyProtocol
    #:protocol-wiring
    class MemosController < ApplicationController
      PAGE_404 = "404.html"

      #~update
      endpoint Memo::Operation::Update, protocol: MyProtocol do
        {
          Output(:fail_fast) => Track(:not_found)
        }
      end
      #~update end

      def update
        invoke Memo::Operation::Update, protocol: true, params: params do
          # success   { |ctx, model:, **| redirect_to memo_path(model.id) }
          # failure   { |ctx, contract:, **| render partial: "form", object: contract }
          # not_authorized { |**| head 403 }
          # not_authenticated { |**| head 401 }
          not_found { |ctx, **| render file: PAGE_404, status: :not_found }
        end
      end
    end
    #:protocol-wiring end
  end #F

  test "{fail_fast} is wired to {not_found}" do
  # not_found
    post "/po/f/update", params: {}
    assert_response 404
    assert_equal "Nothing found!\n", response.body
  end
  # module Dd
  #   #:dd-controller
  #   class ApplicationController < ActionController::Base
  #     include Trailblazer::Endpoint::Controller.module

  #     #~endpoint
  #     endpoint do
  #       options do
  #         {
  #           #~misc
  #           protocol: ::ApplicationController::Endpoint::Protocol,
  #           #~misc end
  #           # default wiring, applied to all endpoints:
  #           protocol_block: -> do
  #             if to_h[:outputs].find { |output| output.semantic == :not_found }
  #               {Output(:not_found) => End(:not_found)}
  #             else
  #               {}
  #             end
  #           end
  #         }
  #       end
  #       #~misc
  #       ctx do |controller:, **|
  #         {
  #           params: controller.params,
  #         }
  #       end
  #       #~misc end
  #     end
  #     #~endpoint end
  #   end
  #   #:dd-controller end

  #   class MemosController < ApplicationController
  #     # TODO: add Update?
  #     endpoint Memo::Operation::Create

  #     def create
  #       invoke Memo::Operation::Create, protocol: true do
  #         success   { |ctx, model:, **| redirect_to memo_path(id: model.id) }
  #         failure   { |*| head 401 }
  #       end
  #     end
  #   end
  # end
end

