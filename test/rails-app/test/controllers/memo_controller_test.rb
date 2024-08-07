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
      end
    end

    class MemosController < ApplicationController
      endpoint Memo::Operation::Create # per default, wire {:fail_fast} to {:failure}.
      #do
      #   {
      #     Output(:fail_fast) => Track(:failure)
      #   }
      # end

      def create
        invoke Memo::Operation::Create do
          # failure is inherited
          success { |ctx, model:, **| redirect_to memo_path(id: model.id) }
        end
      end
    end
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


  test "all possible outcomes with {Create}" do

  # 401
    post "/memos", params: {memo: {}}
    assert_response 401
    assert_equal "", response.body


  # 201
    post "/memos", params: {memo: {id: 1, text: "Remember that!"}}
    assert_redirected_to "/memos/1"
  end

  # fail_fast is wired to failure
  test "{fail_fast} wired to {failure}" do
    post "/a", params: {} # fail_fast
    assert_response 401
  end

    test "explicit {fail_fast} matcher in controller" do
    post "/b", params: {} # fail_fast
    assert_response 500
  end
end
