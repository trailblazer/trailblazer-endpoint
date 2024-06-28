require "test_helper"

class ControllerTest < Minitest::Spec
  module Memo
    module Operation
      class Create < Trailblazer::Operation
        step :validate

        def validate(ctx, seq: [], **)
          seq << :validate
        end
      end
    end
  end

  it "#endpoint" do
    application_controller = Class.new do
      include Trailblazer::Endpoint::Controller::DSL
      # include Trailblazer::Endpoint::Controller.module(run_method: :invoke)

      # OVERRIDE by user
      # Usually this would be done in the ApplicationController.
      def self.default_matcher_for_endpoint
        {
          success:        ->(*) { raise },
          not_found:      ->(ctx, model:, **) { render "404, #{model} not found" },
          not_authorized: ->(ctx, current_user:, **) { render "403, #{current_user}" },
        }
      end
      # TODO: flow_options, kws

      #
      # Runtime
      #
      # Usually this would be done in the ApplicationController.
      def options_for_endpoint_ctx(**)
        {
          current_user: Object,
          params: params,
        }
      end
    end

    controller = Class.new(application_controller) do
      #
      # Compile-time
      #
      endpoint Memo::Operation::Create # create "matcher adapter", use default_block

      #
      # Actions
      #
      def create
        invoke Memo::Operation::Create do
          success         { |ctx, model:, **| render model.inspect }
          failure         { |*| render "failure" }
          not_authorized  { |ctx, model:, **| render "not authorized: #{model}" }
        end
      end
    end
  end
end
