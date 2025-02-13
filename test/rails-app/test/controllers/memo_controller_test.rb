require "test_helper"

# TODO: check if we still need this test after we got {protocol_test}.
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

      endpoint do
        invoke do
          {protocol: true}
        end
      end

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

  # {protocol: true}
  module Aa
    Memo = A::Memo

    class MemosController < ApplicationController
      endpoint Memo::Operation::Create # define endpoint.

      def create
        invoke Memo::Operation::Create, protocol: true do # call the endpoint, use matchers:
          success { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          # failure is inherited
          # not_found is inherited
        end
      end
    end
  end # AA

  module B
    Memo = Module.new
    Memo::Operation = A::Memo::Operation

    #:b-controller
    class MemosController < ApplicationController
      #~fast-track
      endpoint Memo::Operation::Create, fast_track_to_railway: false
      #~fast-track end

      def create
        invoke Memo::Operation::Create, protocol: true do
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
        invoke Memo::Operation::Update, protocol: true do
          # failure is inherited
          success   { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          not_found { |ctx, **| head 404 }
        end
      end

      def with_inherited_404_handler
        invoke "inherited 404 handler", protocol: true do
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

        ctx do |controller:, **|
          {
            params: controller.params,
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
        invoke Memo::Operation::Update, protocol: true do
          success   { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          failure   { |ctx, **| head 401 }
        end
      end

      def create
        invoke Memo::Operation::Create, protocol: true do
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
        ctx do |controller:, **|
          {
            params: controller.params,
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
        invoke Memo::Operation::Create, protocol: true do
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
        invoke "create", protocol: true do # endpoint name
          #~action
          success   { |ctx, **| render html: ctx.keys.inspect }
          #~action end
        end
      end
      #~create end

      def create_with_admin
        invoke "create/admin", protocol: true do
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

      def update
        invoke Memo::Operation::Update do
          success { |ctx, variables:, **| render html: variables }
        end
      end

      MyBucket = Object
      #~runtime
      def update_with_runtime_variables
        invoke Memo::Operation::Update, storage: MyBucket, protocol: true do
          #~misc
          success { |ctx, variables:, **| render html: variables }
          #~misc end
        end
      end
      #~runtime end
    end
    #:f-controller end
  end

  module G
    Memo = Module.new
    #:alias-op
    module Memo::Operation
      class Update < Trailblazer::Operation
        # ...
        step :build_contract
        step :validate_contract

        def build_contract(ctx, **)
          ctx[:"contract.default"] = Object
        end

        def validate_contract(ctx, contract:, **)
          # ...
          true
        end
      end
    end
    #:alias-op end

    #:g-controller
    class MemosController < ApplicationController
      endpoint Memo::Operation::Update

      def update
        invoke Memo::Operation::Update, protocol: true do
          success { |ctx, contract:, **| render html: contract }
        end
      end
    end
    #:g-controller end
  end

  module H
    Memo = Module.new
    Memo::Operation = A::Memo::Operation

    class MemosController < ApplicationController
      # endpoint Memo::Operation::Update

      def create
        invoke Memo::Operation::Create, protocol: false do
          success { |ctx, model:, **| render html: model }
          failure { |ctx, **| head 404 } # never called with {Create}
          fail_fast { |ctx, **| head 500 }
        end
      end
    end
  end


  # Invoke operation directly, {protocol: false} is configured statically.
  module I
    Memo = Module.new
    Memo::Operation = A::Memo::Operation

    class MemosController < ApplicationController
      # endpoint Memo::Operation::Update
      endpoint do
        invoke do # DISCUSS: should we inject {:activity} here? question is, do we need it?
          {protocol: false}
        end
      end

      def create
        invoke Memo::Operation::Create, protocol: true do
          success { |ctx, model:, **| render html: model }
          failure { |ctx, **| head 404 } # never called with {Create}
          fail_fast { |ctx, **| head 500 }
        end
      end
    end
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

  # {protocol: true} works
  test "{protocol: true} uses endpoint" do
  # 201
    post "/aa", params: {memo: {id: 1, text: "Remember that!"}}
    assert_redirected_to "/memos/1"

  # 401
    post "/aa", params: {} # fail_fast
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

  test "we can set aliases through flow_options" do
    post "/g", params: {}
    assert_equal "Object", response.body
  end

  test "{protocol: false} can run OPs without an endpoint" do
    # success
    post "/h", params: {memo: {id: 1}}
    assert_equal "#&lt;struct Memo id=&quot;1&quot;, text=nil&gt;", response.body

    # fail_fast
    post "/h", params: {}
    assert_response 500
  end

  test "{protocol: false} can be set on controller level via {::invoke}" do
    # success
    post "/i", params: {memo: {id: 1}}
    assert_equal "#&lt;struct Memo id=&quot;1&quot;, text=nil&gt;", response.body

    # fail_fast
    post "/i", params: {}
    assert_response 500
  end

  def render(value)
    @render = value
  end

  test "high-level Runtime interface" do #  FIXME: move somewhere to unit test
    Trailblazer::Endpoint::Runtime::Matcher.(
      Memo::Operation::Create,
      {
        params: ActionController::Parameters.new({memo: {}})
      },

      flow_options: ApplicationController._flow_options(controller: nil, activity: nil),

      matcher_context: self,  # FIXME: default via abstraction
      default_matcher: {},    # FIXME: default via abstraction
    ) do
      success { |ctx, **| render "success from API!!!" }
    end

    assert_equal @render, "success from API!!!"
  end
end
