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

    #:endpoint-controller
    #:endpoint-controller-head
    class MemosController < ApplicationController
    #:endpoint-controller-head end
      endpoint Memo::Operation::Create # define endpoint.

      def create
        invoke Memo::Operation::Create do # call the endpoint, use matchers:
          success { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          # failure is inherited
          # not_found is inherited
        end
      end
    end
    #:endpoint-controller end
  end # A

  module B
    Memo = Module.new
    Memo::Operation = A::Memo::Operation

    class MemosController < ApplicationController
      endpoint Memo::Operation::Create, fast_track_to_railway: false

      def create
        invoke Memo::Operation::Create do
          # failure is inherited
          success   { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          fail_fast { |ctx, **| head 500 }
        end
      end
    end
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

  module D
    Memo = C::Memo

    class MemosController < ApplicationController
      endpoint Memo::Operation::Update do
        {
          Output(:not_found) => End(:failure)
        }
      end

      def update
        invoke Memo::Operation::Update do
          # failure is inherited
          success   { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          # not_found { |ctx, **| head 404 } # this will never be hit.
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
end
