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

      def create
        invoke Memo::Operation::Create do
          success         { |ctx, model:, **| render model.inspect }
          failure         { |*| render "failure" } # inherit "failure"
          # not_authorized  { |ctx, current_user:, **| render "not authorized: #{current_user}" } # inherit "not_authorized"
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

    assert_equal controller.to_h, {render: %(403, Object)}

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
            data: params.keys,

            context_options: {
              aliases: {"model": :object},
              container_class: Trailblazer::Context::Container::WithAliases,
            }
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
          success         { |ctx, model:, object:, **| render "#{model.inspect} #{object.inspect}" }
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

    assert_equal controller.to_h, {render: %("[:stack, :before_snapshooter, :after_snapshooter, :value_snapshooter, :data, :context_options, :matcher_value] [:params]" "[:stack, :before_snapshooter, :after_snapshooter, :value_snapshooter, :data, :context_options, :matcher_value] [:params]")}

  # Test overriding {Controller#_flow_options}.
  # Test that we can call {super}.
  # Test that we have access to {**options} from {#invoke}.
    controller_class = Class.new(application_controller) do
      endpoint Memo::Operation::Create # create "matcher adapter", use default_block

      def _flow_options(**options)
        super.merge(
          data: "from _flow_options: #{options.keys}",
        )
      end
      #
      # Actions
      #
      def create
        invoke Memo::Operation::Create, event: "create!" do
          success         { |ctx, model:, object: nil, **| render "#{model.inspect} #{object.inspect}" }
          # failure         { |*| render "failure" }
          # not_authorized  { |ctx, current_user:, **| render "not authorized: #{current_user}" }
        end
      end
    end

    controller = controller_class.new(params: {id: 1})
    controller.create

    assert_equal controller.to_h, {:render=>"\"[:stack, :before_snapshooter, :after_snapshooter, :value_snapshooter, :data, :context_options, :matcher_value] from _flow_options: [:event]\" \"[:stack, :before_snapshooter, :after_snapshooter, :value_snapshooter, :data, :context_options, :matcher_value] from _flow_options: [:event]\""}
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

class UnconfiguredControllerTest < Minitest::Spec
  Memo = ControllerTest::Memo

  it "no configuration" do
    application_controller = Class.new do
      include ControllerTest::Controller # Test module

      include Trailblazer::Endpoint::Controller.module

      class Protocol < Trailblazer::Endpoint::Protocol
        include T.def_steps(:authenticate, :policy)
      end

      # We omit any configuration.
      #
      endpoint do
        options do
          {protocol: Protocol, adapter: Trailblazer::Endpoint::Adapter} # DISCUSS: currently you have to provide the Protocol, for "security" reasons.
        end
      end
    end

    controller_class = Class.new(application_controller) do
      endpoint Memo::Operation::Create # name: "Memo::Operation::Create"

      def create
        invoke Memo::Operation::Create, seq: [] do
          success { |ctx, model:, **| render model.inspect }
        end
      end
    end

    # success
    controller = controller_class.new(params: {id: 1})
    controller.create

    assert_equal controller.to_h, {render: %(Module)}
  end
end

class ControllerWithOperationAndFastTrackTest < Minitest::Spec
  module Memo
    module Operation
      class Create < Trailblazer::Activity::FastTrack
        step :model, Output(:failure) => End(:not_found)
        step :validate, fast_track: true

        include T.def_steps(:model, :validate)
      end
    end
  end

  it "Controller running an operation stopping on all four termini" do
    application_controller = Class.new do
      include ControllerTest::Controller # Test module

      include Trailblazer::Endpoint::Controller.module

      # we automatically wire fast tracks to conventional termini.
      class Protocol < Trailblazer::Endpoint::Protocol::Operation # TODO: "TEST WITH ADDITIONAL domain_activity In()"
        include T.def_steps(:authenticate, :policy)
      end

      # TODO: allow {inherit: true} to override/add only particular keys.
      endpoint do
        options do
          {
            protocol: Protocol,
          }
        end

        default_matcher do
          {}
        end

        ctx do
          {
            **params,
            seq: [],
          }
        end
      end
    end

    controller_class = Class.new(application_controller) do
      endpoint "explicit fast_track", domain_activity: Memo::Operation::Create
      endpoint "binary", domain_activity: Memo::Operation::Create, fast_track_to_railway: true # fast track outputs are wired to railway termini.
      endpoint "custom wiring", domain_activity: Memo::Operation::Create do
        {
          Output(:fail_fast) => End(:failure),
          Output(:pass_fast) => End(:success),
          Output(:success) => End(:failure),
          Output(:not_found) => End(:fail_fast),
        }
      end
      # re-introduce the {fail_fast} outcome manuall,
      # implying that we can mix and override wiring options.
      endpoint "binary and custom wiring", domain_activity: Memo::Operation::Create, fast_track_to_railway: true do
        {
          Output(:not_found) => End(:fail_fast),
        }
      end

      def create
        invoke "explicit fast_track" do
          success   { |ctx, **| render "success" }
          fail_fast { |*| render "yay, fast_track!" }
          failure   { |*| render "failure" }
          pass_fast { |*| render "hooray, pass_fast!" }
          not_found { |*| render "404" }
        end
      end

      def with_binary
        invoke "binary" do
          success   { |ctx, **| render "success" }
          failure   { |*| render "failure" }
          not_found { |*| render "404" }
        end
      end

      def with_custom_wiring
        invoke "custom wiring" do
          success   { |ctx, **| render "success" }
          failure   { |*| render "failure" }
          fail_fast { |*| render "404" }
        end
      end

      def with_binary_and_custom_wiring
        invoke "binary and custom wiring" do
          success   { |ctx, **| render "success" }
          failure   { |*| render "failure" }
          fail_fast { |*| render "fail_fast" }
        end
      end
    end

# explicit fast track
    # success
    controller = controller_class.new({})
    controller.create

    assert_equal controller.to_h, {render: %(success)}

    # failure
    controller = controller_class.new({validate: false})
    controller.create

    assert_equal controller.to_h, {render: %(failure)}

    # fail_fast
    controller = controller_class.new({validate: Trailblazer::Activity::FastTrack::FailFast})
    controller.create

    assert_equal controller.to_h, {render: %(yay, fast_track!)}

    # pass_fast
    controller = controller_class.new({validate: Trailblazer::Activity::FastTrack::PassFast})
    controller.create

    assert_equal controller.to_h, {render: %(hooray, pass_fast!)}

    # not_found
    controller = controller_class.new({model: false})
    controller.create

    assert_equal controller.to_h, {render: %(404)}

# binary, fast_track gets routed to railway
    # success
    controller = controller_class.new({})
    controller.with_binary

    assert_equal controller.to_h, {render: %(success)}

    # failure
    controller = controller_class.new({validate: false})
    controller.with_binary

    assert_equal controller.to_h, {render: %(failure)}

    # fail_fast
    controller = controller_class.new({validate: Trailblazer::Activity::FastTrack::FailFast})
    controller.with_binary

    assert_equal controller.to_h, {render: %(failure)}

    # pass_fast
    controller = controller_class.new({validate: Trailblazer::Activity::FastTrack::PassFast})
    controller.with_binary

    assert_equal controller.to_h, {render: %(success)}

    # not_found
    controller = controller_class.new({model: false})
    controller.with_binary

    assert_equal controller.to_h, {render: %(404)}

  # custom wiring
    # success
    controller = controller_class.new({})
    controller.with_custom_wiring
    assert_equal controller.to_h, {render: %(failure)}

    # failure
    controller = controller_class.new({validate: false})
    controller.with_custom_wiring
    assert_equal controller.to_h, {render: %(failure)}

    # fail_fast
    controller = controller_class.new({validate: Trailblazer::Activity::FastTrack::FailFast})
    controller.with_custom_wiring
    assert_equal controller.to_h, {render: %(failure)}

    # pass_fast
    controller = controller_class.new({validate: Trailblazer::Activity::FastTrack::PassFast})
    controller.with_custom_wiring
    assert_equal controller.to_h, {render: %(success)}

    # not_found
    controller = controller_class.new({model: false})
    controller.with_custom_wiring
    assert_equal controller.to_h, {render: %(404)}

  # binary and custom wiring
    # success
    controller = controller_class.new({})
    controller.with_binary_and_custom_wiring
    assert_equal controller.to_h, {render: %(success)}

    # failure
    controller = controller_class.new({validate: false})
    controller.with_binary_and_custom_wiring
    assert_equal controller.to_h, {render: %(failure)}

    # fail_fast
    controller = controller_class.new({validate: Trailblazer::Activity::FastTrack::FailFast})
    controller.with_binary_and_custom_wiring
    assert_equal controller.to_h, {render: %(failure)}

    # pass_fast
    controller = controller_class.new({validate: Trailblazer::Activity::FastTrack::PassFast})
    controller.with_binary_and_custom_wiring
    assert_equal controller.to_h, {render: %(success)}

    # not_found
    controller = controller_class.new({model: false})
    controller.with_binary_and_custom_wiring
    assert_equal controller.to_h, {render: %(fail_fast)}
  end
end
