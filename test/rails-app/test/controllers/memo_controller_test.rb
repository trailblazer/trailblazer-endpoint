require "test_helper"

class MemoControllerTest < ActionDispatch::IntegrationTest
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

    #:endpoint-controller-head
    #:endpoint-controller
    class MemosController < ApplicationController
    #:endpoint-controller-head end
      #~define
      endpoint Memo::Operation::Create # define endpoint.
      #~define end

      #~create
      def create
        invoke Memo::Operation::Create do # call the endpoint, use matchers:
          success { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          # failure is inherited
          # not_found is inherited
        end
      end
      #~create end
    end
    #:endpoint-controller end
  end # A

  module B
    Memo = Module.new
    Memo::Operation = A::Memo::Operation

    #:b-controller
    class MemosController < ApplicationController
      #~fast-track
      endpoint Memo::Operation::Create, fast_track_to_railway: false
      #~fast-track end

      def create
        invoke Memo::Operation::Create do
          # failure is inherited
          success   { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          fail_fast { |ctx, **| head 500 }
        end
      end
    end
    #:b-controller end
  end

  module C
    Memo = Module.new
    module Memo::Operation
      class Update < Trailblazer::Operation
        step :find_model, Output(:failure) => End(:not_found)

        def find_model(ctx, params:, **)
          params[:id]
        end
      end
    end

    class MemosController < ApplicationController
      endpoint Memo::Operation::Update # has explicit {:not_found} terminus.
      endpoint "inherited 404 handler", domain_activity: Memo::Operation::Update

      def update
        invoke Memo::Operation::Update do
          # failure is inherited
          success   { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          not_found { |ctx, **| head 404 }
        end
      end

      def with_inherited_404_handler
        invoke "inherited 404 handler" do
          success   { |ctx, model:, **| redirect_to memo_path(id: model.id) }
        end
      end
    end
  end

  # ApplicationController statically adds {not_found} wiring.
  module D
    Memo = C::Memo
    Memo::Operation::Create = ::Memo::Operation::Create

    #:d-controller
    class ApplicationController < ActionController::Base
      include Trailblazer::Endpoint::Controller.module

      endpoint do
        #~options
        options do
          {
            #~protocol
            protocol: ::ApplicationController::Endpoint::Protocol,
            #~protocol end
            fast_track_to_railway: true, # FIXME: test this!
            # default wiring, applied to all endpoints:
            protocol_block: -> do
              {Output(:not_found) => End(:not_found)}
            end
          }
        end
        #~options end

        ctx do # this block is executed in controller instance context.
          {
            params: params,
          }
        end
      end
    end
    #:d-controller end

    #:d-memo
    class MemosController < ApplicationController
      #~endpoint
      endpoint Memo::Operation::Update do
        {
          Output(:not_found) => End(:failure)
        }
      end
      #~endpoint end

      #:empty
      endpoint Memo::Operation::Create do
        {} # override ApplicationController's wiring.
      end
      #:empty end

      def update
        invoke Memo::Operation::Update do
          success   { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          failure   { |ctx, **| head 401 }
        end
      end

      def create
        invoke Memo::Operation::Create do
          success   { |ctx, model:, **| head 201 }
          failure   { |ctx, **| head 401 }
        end
      end
    end
    #:d-memo end
  end
  module Dd
    #:dd-controller
    class ApplicationController < ActionController::Base
      include Trailblazer::Endpoint::Controller.module

      #~endpoint
      endpoint do
        options do
          {
            #~misc
            protocol: ::ApplicationController::Endpoint::Protocol,
            #~misc end
            # default wiring, applied to all endpoints:
            protocol_block: -> do
              if to_h[:outputs].find { |output| output.semantic == :not_found }
                {Output(:not_found) => End(:not_found)}
              else
                {}
              end
            end
          }
        end
        #~misc
        ctx do # this block is executed in controller instance context.
          {
            params: params,
          }
        end
        #~misc end
      end
      #~endpoint end
    end
    #:dd-controller end

    class MemosController < ApplicationController
      # TODO: add Update?
      endpoint Memo::Operation::Create

      def create
        invoke Memo::Operation::Create do
          success   { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          failure   { |*| head 401 }
        end
      end
    end
  end

  module E
    Memo = Module.new
    Memo::Operation = A::Memo::Operation

    Protocol = Class.new(ApplicationController::Endpoint::Protocol)
    Protocol::Admin = Class.new(ApplicationController::Endpoint::Protocol) do
      step ->(ctx, **) { ctx[:admin] = true }
    end

    #:e-controller
    class MemosController < ApplicationController
      #~domain_activity
      endpoint "create", domain_activity: Memo::Operation::Create
      endpoint "create/admin",
        domain_activity: Memo::Operation::Create,
        protocol: Protocol::Admin
      #~domain_activity end

      #~create
      def create
        invoke "create" do # endpoint name
          #~action
          success   { |ctx, **| render html: ctx.keys.inspect }
          #~action end
        end
      end
      #~create end

      def create_with_admin
        invoke "create/admin" do
          success   { |ctx, admin:, **| render html: admin.inspect + ctx.keys.inspect }
        end
      end
    end
    #:e-controller end
  end

  module F
    Memo = Module.new
    #:params-keys
    module Memo::Operation
      class Update < Trailblazer::Operation
        step :find_model
        #~misc
        step :inspect_ctx
        def inspect_ctx(ctx, **)
          ctx[:variables] = ctx.keys.inspect
        end
        #~misc end
        def find_model(ctx, **)
          p ctx.keys.inspect # => [:params, :current_user]
        end
      end
    end
    #:params-keys end

=begin
#:storage
def find_model(ctx, **)
  p ctx.keys.inspect # => [:params, :current_user, :storage]
end
#:storage end
=end

    #:f-controller
    class MemosController < ApplicationController
      endpoint Memo::Operation::Update
      endpoint "inherited 404 handler", domain_activity: Memo::Operation::Update

      def update
        invoke Memo::Operation::Update do
          success { |ctx, variables:, **| render html: variables }
        end
      end

      MyBucket = Object
      #~runtime
      def update_with_runtime_variables
        invoke Memo::Operation::Update, storage: MyBucket do
          #~misc
          success { |ctx, variables:, **| render html: variables }
          #~misc end
        end
      end
      #~runtime end
    end
    #:f-controller end
  end

  # fail_fast is wired to failure
  test "{fail_fast} wired to {failure}" do
  # 201
    post "/a", params: {memo: {id: 1, text: "Remember that!"}}
    assert_redirected_to "/memos/1"

  # 401
    post "/a", params: {} # fail_fast
    assert_response 401
    assert_equal "", response.body
  end

  test "explicit {fail_fast} matcher in controller" do
    post "/b", params: {} # fail_fast
    assert_response 500
  end

  test "{not_found} has explicit matcher" do
    post "/c", params: {}
    assert_response 404
    assert_equal "", response.body

  # {not_found} has inherited matcher
    post "/a", params: {} # fail_fast
    assert_response 401
    assert_equal "", response.body
  end

  test "{not_found} has inherited matcher" do
    post "/c_inherited", params: {} # not_found
    assert_response 404
    assert_equal "ID  not found.", response.body
  end

  test "{not_found} wired to {failure}" do
    post "/d", params: {}
    assert_response 401 # failure
  end

  test "Create has default wirings" do
    post "/d_create", params: {memo: {id: 1}}
    assert_response 201 # failure
  end

  test "{not_found} not wired as {Create} doesn't have that output" do
    post "/dd", params: {}
    assert_response 401 # failure
  end

  test "two different endpoints but same constant" do
    post "/e", params: {memo: {id: 1}} # DISCUSS: WTF Rails? If we omit {id: 1}, the entire params structure is not passed to the controller.
    assert_equal response.body, %([:params, :current_user, :model])

    post "/e_admin", params: {memo: {id: 1}}
    assert_equal response.body, %(true[:params, :current_user, :model, :admin])
  end

  test "Update can see {ctx.keys}" do
    post "/f", params: {}
    assert_equal "[:params, :current_user]", response.body
  end

  test "we can pass ctx variables at runtime" do
    post "/f_with_runtime_variables", params: {}
    assert_equal "[:params, :current_user, :storage]", response.body
  end
end
