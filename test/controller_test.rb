require "test_helper"

class ControllerTest < Minitest::Spec
  module Controller
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
  end

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

  it "Controller with inherited Declarative::State" do
    application_controller = Class.new do
      include Controller # Test module

      include Trailblazer::Endpoint::Controller.module

      class Protocol < Trailblazer::Endpoint::Protocol
        include T.def_steps(:authenticate, :policy)
      end

      # TODO: allow {inherit: true} to override/add only particular keys.
      endpoint do
        options do
          {
            protocol: Protocol,
            adapter: Trailblazer::Endpoint::Adapter,
          }
        end

        default_matcher do
          {
            success:        ->(*) { raise },
            not_found:      ->(ctx, model:, **) { render "404, #{model} not found" },
            not_authorized: ->(ctx, current_user:, **) { render "403, #{current_user}" },
            not_authenticated: ->(*) { render "authentication failed" }
          }
        end

        ctx do
          {
            current_user: Object,
            **params,
            seq: [],
          }
        end
      end

      # TODO: flow_options, kws
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

    empty_sub_controller_class = Class.new(controller_class)

    overriding_ctx_sub_controller_class = Class.new(controller_class) do
      endpoint do
        ctx do
          {
            seq: [1, 2, 3],
          }
        end
      end

      def create
        invoke Memo::Operation::Create do
          success         { |ctx, seq:, **| render "#{seq.inspect} #{ctx.keys}" }
        end
      end
    end

    overriding_matcher_sub_controller_class = Class.new(controller_class) do
      endpoint do

        default_matcher do
          {
            not_authenticated: ->(*) { render "absolutely no way, 401" },
          }
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


  # Simply inherit the behavior
    # success
    controller = empty_sub_controller_class.new(params: {id: 1})
    controller.create

    assert_equal controller.to_h, {render: %(Module)}

    # not_authorized
    controller = empty_sub_controller_class.new(params: {id: 1}, policy: false)
    controller.create

    assert_equal controller.to_h, {render: %(not authorized: Object)}

    # not_authenticated
    controller = empty_sub_controller_class.new(params: {id: 1}, authenticate: false)
    controller.create

    assert_equal controller.to_h, {render: %(authentication failed)}

    # failure
    controller = empty_sub_controller_class.new(params: {id: 1}, validate: false)
    controller.create

    assert_equal controller.to_h, {render: %(failure)}


  # Override ctx
    # success
    controller = overriding_ctx_sub_controller_class.new(params: {id: 1})
    controller.create

    assert_equal controller.to_h, {render: %([1, 2, 3, :authenticate, :policy, :validate] [:seq, :model])}


  # Override default_matcher
    # success
    controller = overriding_matcher_sub_controller_class.new(params: {id: 1})
    controller.create

    assert_equal controller.to_h, {render: %(Module)}

    # not_authorized
    controller = overriding_matcher_sub_controller_class.new(params: {id: 1}, policy: false)
    controller.create

    assert_equal controller.to_h, {render: %(not authorized: Object)}

    # not_authenticated
    controller = overriding_matcher_sub_controller_class.new(params: {id: 1}, authenticate: false)
    controller.create

    assert_equal controller.to_h, {render: %(absolutely no way, 401)}

    # failure
    controller = overriding_matcher_sub_controller_class.new(params: {id: 1}, validate: false)
    controller.create

    assert_equal controller.to_h, {render: %(failure)}
  end
end

class ControllerWithInheritanceButOverridingViaMethodsTest < Minitest::Spec
  it do
    application_controller = Class.new do
      include ControllerTest::Controller # Test module

      include Trailblazer::Endpoint::Controller.module

      class Protocol < Trailblazer::Endpoint::Protocol
        include T.def_steps(:authenticate, :policy)
      end

      # TODO: flow_options, kws

      #
      # Runtime
      #
      # Usually this would be done in the ApplicationController.
      def _options_for_endpoint_ctx(**)
        {
          current_user: Object,
          **params,
          seq: [],
        }
      end

      def self._options_for_endpoint
        {
          protocol: Protocol,
          adapter: Trailblazer::Endpoint::Adapter
        }
      end

      def _default_matcher_for_endpoint
        {
          success:        ->(*) { raise },
          not_found:      ->(ctx, model:, **) { render "404, #{model} not found" },
          not_authorized: ->(ctx, current_user:, **) { render "403, #{current_user}" },
          not_authenticated: ->(*) { render "authentication failed" }
        }
      end
    end

    Memo = ControllerTest::Memo

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

# NOTE: this is a private test making sure our internal API is feasible without inheritance logic.
class ControllerWithoutInheritanceTest < Minitest::Spec
  Memo = ControllerTest::Memo

  it "Controller that's not using Declarative::State and doesn't implement inheritance" do
    application_controller = Class.new do
      include ControllerTest::Controller # Test module

      extend Trailblazer::Endpoint::Controller::DSL
      # include Trailblazer::Endpoint::Controller::Config
      # extend Trailblazer::Endpoint::Controller::State::Config::ClassMethods
      # include Trailblazer::Endpoint::Controller.module(run_method: :invoke)
      include Trailblazer::Endpoint::Controller::Runtime


# DISCUSS: necessary API to store/retrieve config values.
      def self._endpoints
        instance_variable_get(:@endpoints)
      end

      # readonly
      def _endpoints
        self.class._endpoints
      end

      def _default_matcher_for_endpoint
        self.class.default_matcher_for_endpoint
      end

      def _options_for_endpoint_ctx
        options_for_endpoint_ctx
      end

      def _flow_options
        {}
      end
# /end

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

      def self._options_for_endpoint
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
      instance_variable_set(:@endpoints, {})

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

class ControllerWithFlowOptionsTest < Minitest::Spec
  module Memo
    module Operation
      class Create < Trailblazer::Activity::Railway
        step task: :model

        def model((ctx, flow_options),  **circuit_options)
          ctx[:model] = flow_options.keys.inspect + " #{flow_options[:data]}"

          return Trailblazer::Activity::Right, [ctx, flow_options]
        end
      end
    end
  end

  it "Controller" do
    application_controller = Class.new do
      include ControllerTest::Controller # Test module

      include Trailblazer::Endpoint::Controller.module

      class Protocol < Trailblazer::Endpoint::Protocol
        include T.def_steps(:authenticate, :policy)
      end

      # TODO: allow {inherit: true} to override/add only particular keys.
      endpoint do
        options do
          {
            protocol: Protocol,
            adapter: Trailblazer::Endpoint::Adapter,
          }
        end

        ctx do
          {
            current_user: Object,
            **params,
            seq: [],
          }
        end

        flow_options do
          {
            data: "special",
          }
        end
      end

    end

    controller_class = Class.new(application_controller) do
      endpoint Memo::Operation::Create # create "matcher adapter", use default_block

      #
      # Actions
      #
      def create
        invoke Memo::Operation::Create do
          success         { |ctx, model:, **| render model.inspect }
          # failure         { |*| render "failure" }
          # not_authorized  { |ctx, current_user:, **| render "not authorized: #{current_user}" }
        end
      end
    end

    #
    # Test
    #

    # success
    controller = controller_class.new(params: {id: 1})
    controller.create

    assert_equal controller.to_h, {render: %("[:stack, :before_snapshooter, :after_snapshooter, :value_snapshooter, :data, :matcher_value] special")}
  end
end

class ControllerWithSeveralIdenticalEndpointsTest < Minitest::Spec
  Memo = ControllerTest::Memo

  it "provides {:id} option for {#endpoint}" do
    application_controller = Class.new do
      include ControllerTest::Controller # Test module

      include Trailblazer::Endpoint::Controller.module

      class Protocol < Trailblazer::Endpoint::Protocol
        include T.def_steps(:authenticate, :policy)
      end

      # TODO: allow {inherit: true} to override/add only particular keys.
      endpoint do
        options do
          {
            protocol: Protocol,
            adapter: Trailblazer::Endpoint::Adapter,
          }
        end

        ctx do
          {
            current_user: Object,
            **params,
            seq: [],
          }
        end
      end
    end

    controller_class = Class.new(application_controller) do
      endpoint Memo::Operation::Create # name: "Memo::Operation::Create"
      endpoint "Create again", domain_activity: Memo::Operation::Create # this probably won't be used by anyone except {workflow}.

      #
      # Actions
      #
      def create
        invoke Memo::Operation::Create do
          success { |ctx, model:, **| render model.inspect }
        end
      end

      def create_again
        invoke "Create again" do
          success { |ctx, model:, **| render "again: #{model.inspect}" }
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

    controller = controller_class.new(params: {id: 1})
    controller.create_again

    assert_equal controller.to_h, {render: %(again: Module)}
  end
end
