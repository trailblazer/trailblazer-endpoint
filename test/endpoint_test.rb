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

  it "allows identical endpoint constants with different {:name}" do
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

end
