require "test_helper"

class NoProtocolTest < ActionDispatch::IntegrationTest
  # no config of endpoints.
  #:application-controller
  class ApplicationController < ActionController::Base
    #~include
    include Trailblazer::Endpoint::Controller.module
    #~include end

    endpoint do
      #~flow_options
      flow_options do |**|
        {
          context_options: {
            aliases: {"contract.default": :contract},
            container_class: Trailblazer::Context::Container::WithAliases,
          }
        }
      end
      #~flow_options end
    end
  end
  #:application-controller end

  module A
    Memo = Module.new

    module Memo::Operation
      class Create < Trailblazer::Operation
        step :validate#, fail_fast: true
        step :model

        def validate(ctx, params:, **)
          ctx[:"contract.default"] = Struct.new(:errors).new({title: ["must be filled"]})
          params[:memo]
        end

        def model(ctx, params:, **)
          ctx[:model] = ::Memo.create(**params[:memo].permit!)
        end
      end
    end

    #:controller
    class MemosController < ApplicationController
      #~create
      def create
        invoke Memo::Operation::Create, params: params, protocol: false do #  FIXME: protocol should be false per default.
          success { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          failure { |ctx, contract:, **|
            render partial: "form", locals: {contract: contract}
          }
        end
      end
      #~create end
    end
    #:controller end
  end # A

  test "pass everything explicitly to {#invoke}" do
    post "/no/a", params: {memo: {id: 1, text: "Remember that!"}}
    assert_redirected_to "/memos/1"

    post "/no/a", params: {}
    assert_equal "<form>\n  {:title=&gt;[&quot;must be filled&quot;]}\n</form>\n", response.body
  end


  # {endpoint.ctx} is defined.
  # We don't need {params: params} being passed to {#invoke}.
  module B
    class ApplicationController < ActionController::Base
      include Trailblazer::Endpoint::Controller.module

      #:b-endpoint-dsl
      endpoint do
        flow_options do |**|
          {
            context_options: {
              aliases: {"contract.default": :contract},
              container_class: Trailblazer::Context::Container::WithAliases,
            }
          }
        end
        #~ctx
        ctx do |controller:, **|
          {
            params: controller.params,
          }
        end
        #~ctx end
      end
      #:b-endpoint-dsl end
    end

    Memo = A::Memo

    class MemosController < ApplicationController
      #:b-create
      def create
        invoke Memo::Operation::Create, protocol: false do
          #~skip
          success { |ctx, model:, **| redirect_to memo_path(id: model.id) }
          failure { |ctx, contract:, **|
            render partial: "form", locals: {contract: contract}
          }
          #~skip end
        end
      end
      #:b-create end
    end
  end # B

  test "{endpoint.ctx} passes {params} to {#invoke}" do
    post "/no/b", params: {memo: {id: 1, text: "Remember that!"}}
    assert_redirected_to "/memos/1"

    post "/no/b", params: {}
    assert_equal "<form>\n  {:title=&gt;[&quot;must be filled&quot;]}\n</form>\n", response.body
  end
end
