require "test_helper"

# Test Controller.endpoint-specific logic like compiling endpoints and running those.
# Do *not* test routing, wiring, matchers etc as those parts are already covered
# in controller_unit_test.rb.
class EndpointTest < ControllerTest
  let(:application_controller) do
    controller do
      endpoint do
        ctx do |controller:, **|
          {seq: [], **controller.input}
        end

        default_matcher do
          {
            not_authenticated: ->(ctx, seq:, **) { render "401 #{seq.inspect}" },
            success: ->(ctx, seq:, **) { render seq.inspect },
            failure: ->(ctx, seq:, **) { render "500 #{seq.inspect}" },
          }
        end
      end
    end
  end

  let(:protocol) do
    protocol = Class.new(Trailblazer::Activity::Railway) do
      terminus :not_found
      terminus :not_authenticated
      # terminus :not_authorized

      step :authenticate, Output(:failure) => Track(:not_authenticated)
      step nil, id: :domain_activity  # {Memo::Operation::Create} gets placed here.

      include T.def_steps(:authenticate)
    end
  end

  it "basic setup, nothing endpoint-specific defaulted" do
    protocol = self.protocol

    controller_class = Class.new(application_controller) do
      endpoint Memo::Operation::Create, protocol: protocol

      def create
        invoke Memo::Operation::Create, protocol: true do end
      end
    end

    assert_runs(controller_class, :create,
      success:   {render: %([:authenticate, :validate])},
      failure: {render: %(500 [:authenticate, :validate]), validate: false},
      not_authenticated: {render: %(401 [:authenticate]), authenticate: false}
    )
  end

  it "allows identical endpoint constants with different name using {:domain_activity}" do
    protocol = self.protocol

    controller_class = Class.new(application_controller) do
      endpoint Memo::Operation::Create, protocol: protocol
      endpoint "Create again", domain_activity: Memo::Operation::Create, protocol: protocol

      def create
        invoke Memo::Operation::Create, protocol: true do end
      end

      def create_again
        invoke "Create again", protocol: true do end
      end
    end

    expected_outcomes = {success:   {render: %([:authenticate, :validate])},
      failure: {render: %(500 [:authenticate, :validate]), validate: false},
      not_authenticated: {render: %(401 [:authenticate]), authenticate: false}}

    assert_runs(controller_class, :create, **expected_outcomes)
    assert_runs(controller_class, :create_again, **expected_outcomes)
  end

  describe "activity stopping on all four termini" do
    class Create < Trailblazer::Activity::FastTrack
      step :model, Output(:failure) => End(:not_found)
      step :validate, fast_track: true

      include T.def_steps(:model, :validate)
    end

    it "can be configured using {fast_track_to_railway}, {protocol_block}" do
      protocol = Class.new(self.protocol) do
        terminus :fail_fast
        terminus :pass_fast
      end

      controller_class = Class.new(application_controller) do
        endpoint "explicit fast_track", domain_activity: Create, protocol: protocol
        endpoint "binary", domain_activity: Create, fast_track_to_railway: true, protocol: protocol # fast track outputs are wired to railway termini.
        endpoint "custom wiring", domain_activity: Create, protocol: protocol do
          {
            Output(:fail_fast) => End(:failure),
            Output(:pass_fast) => End(:success),
            Output(:success) => End(:failure),
            Output(:not_found) => End(:fail_fast),
          }
        end
        # re-introduce the {fail_fast} outcome manually,
        # after using {fast_track_to_railway},
        # implying that we can mix and override wiring options.
        endpoint "binary and custom wiring", domain_activity: Create, fast_track_to_railway: true, protocol: protocol do
          {
            Output(:not_found) => End(:fail_fast),
          }
        end

        def create
          invoke "explicit fast_track", protocol: true do
            success   { |ctx, **| render "success" }
            fail_fast { |*| render "yay, fast_track!" }
            failure   { |*| render "failure" }
            pass_fast { |*| render "hooray, pass_fast!" }
            not_found { |*| render "404" }
          end
        end

        def with_binary
          invoke "binary", protocol: true do
            success   { |ctx, **| render "success" }
            failure   { |*| render "failure" }
            not_found { |*| render "404" }
          end
        end

        def with_custom_wiring
          invoke "custom wiring", protocol: true do
            success   { |ctx, **| render "success" }
            failure   { |*| render "failure" }
            fail_fast { |*| render "404" }
          end
        end

        def with_binary_and_custom_wiring
          invoke "binary and custom wiring", protocol: true do
            success   { |ctx, **| render "success" }
            failure   { |*| render "failure" }
            fail_fast { |*| render "fail_fast" }
          end
        end
      end

    # explicit fast track
      assert_runs(
        controller_class, :create,

        success:            {render: %(success)},
        failure:            {render: %(failure), validate: false},
        fail_fast:          {render: %(yay, fast_track!), validate: Trailblazer::Activity::FastTrack::FailFast},
        pass_fast:          {render: %(hooray, pass_fast!), validate: Trailblazer::Activity::FastTrack::PassFast},
        not_found:          {render: %(404), model: false},
      )

        # binary, fast_track gets routed to railway
      assert_runs(
        controller_class, :with_binary,

        success:            {render: %(success)},
        failure:            {render: %(failure), validate: false},
        fail_fast:          {render: %(failure), validate: Trailblazer::Activity::FastTrack::FailFast},
        pass_fast:          {render: %(success), validate: Trailblazer::Activity::FastTrack::PassFast},
        not_found:          {render: %(404), model: false},
      )

    # custom wiring
    assert_runs(
        controller_class, :with_custom_wiring,

        success:            {render: %(failure)},
        failure:            {render: %(failure), validate: false},
        fail_fast:          {render: %(failure), validate: Trailblazer::Activity::FastTrack::FailFast},
        pass_fast:          {render: %(success), validate: Trailblazer::Activity::FastTrack::PassFast},
        not_found:          {render: %(404), model: false},
      )

    # binary and custom wiring
      assert_runs(
        controller_class, :with_binary_and_custom_wiring,

        success:            {render: %(success)},
        failure:            {render: %(failure), validate: false},
        fail_fast:          {render: %(failure), validate: Trailblazer::Activity::FastTrack::FailFast},
        pass_fast:          {render: %(success), validate: Trailblazer::Activity::FastTrack::PassFast},
        not_found:          {render: %(fail_fast), model: false},
      )
    end
  end
end
