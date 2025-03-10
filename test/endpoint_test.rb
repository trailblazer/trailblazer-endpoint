require "test_helper"

# Test Controller.endpoint-specific logic like compiling endpoints and running those.
# Do *not* test routing, wiring, matchers etc as those parts are already covered
# in controller_unit_test.rb.
class EndpointTest < ControllerTest
  it "basic setup, nothing endpoint-specific defaulted" do
    protocol = Class.new(Trailblazer::Activity::Railway) do
      terminus :not_found
      terminus :not_authenticated
      # terminus :not_authorized

      step :authenticate, Output(:failure) => Track(:not_authenticated)
      step nil, id: :domain_activity  # {Memo::Operation::Create} gets placed here.

      include T.def_steps(:authenticate)
    end

    controller_class = controller do
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
end
