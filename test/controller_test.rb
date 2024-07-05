require "test_helper"

class ControllerTest < Minitest::Spec
  module Memo
    module Operation
      class Create < Trailblazer::Activity::Railway
        step :model
        step :validate

        include T.def_steps(:validate)

        def model(ctx, **)
          ctx[:model] = Module
        end
      end
    end
  end

  it "#endpoint" do
    application_controller = Class.new do
      attr_reader :params

      def initialize(params)
        @params = params
      end

      def render(string)
        @render = string
      end

      def to_h
        {
          render: @render,
        }
      end

      extend Trailblazer::Endpoint::Controller::DSL
      # include Trailblazer::Endpoint::Controller.module(run_method: :invoke)
      include Trailblazer::Endpoint::Controller::Runtime

      class Protocol < Trailblazer::Endpoint::Protocol
        include T.def_steps(:authenticate, :policy)
      end

      # OVERRIDE by user
      # Usually this would be done in the ApplicationController.
      def self.default_matcher_for_endpoint
        {
          success:        ->(*) { raise },
          not_found:      ->(ctx, model:, **) { render "404, #{model} not found" },
          not_authorized: ->(ctx, current_user:, **) { render "403, #{current_user}" },
          not_authenticated: ->(*) { render "authentication failed" }
        }
      end
      # self.instance_variable_get(:@default_matcher).merge!(default_matcher_for_endpoint)
      def default_matcher_for_endpoint
        self.class.default_matcher_for_endpoint
      end


      # TODO: flow_options, kws

      #
      # Runtime
      #
      # Usually this would be done in the ApplicationController.
      def options_for_endpoint_ctx(**)
        {
          current_user: Object,
          **params,
          seq: [],
        }
      end

      def self.options_for_endpoint
        {
          protocol: Protocol,
          adapter: Trailblazer::Endpoint::Adapter
        }
      end
    end

    controller_class = Class.new(application_controller) do
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
          not_authorized  { |ctx, current_user:, **| render "not authorized: #{current_user}" }
        end
      end
    end

    #
    # Test
    #

    # success
    controller = controller_class.new(params: {id: 1})
    controller.create

    assert_equal controller.to_h, {render: %(Module)}

    # not_authorized
    controller = controller_class.new(params: {id: 1}, policy: false)
    controller.create

    assert_equal controller.to_h, {render: %(not authorized: Object)}

    # not_authenticated
    controller = controller_class.new(params: {id: 1}, authenticate: false)
    controller.create

    assert_equal controller.to_h, {render: %(authentication failed)}

    # failure
    controller = controller_class.new(params: {id: 1}, validate: false)
    controller.create

    assert_equal controller.to_h, {render: %(failure)}
  end
end
