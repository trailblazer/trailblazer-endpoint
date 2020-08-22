require "test_helper"

class AdapterWebTest < Minitest::Spec
  it "AdapterWeb / perfect 2.1 OP scenario (with {not_found} terminus" do
    activity = Class.new(Trailblazer::Activity::Railway) do
      step :model, Output(:failure) => End(:not_found)
      step :validate

      include T.def_steps(:validate, :model)
    end

    protocol = Class.new(Trailblazer::Endpoint::Protocol) do # DISCUSS: what to to with authenticate and policy?
      include T.def_steps(:authenticate, :policy)
    end

    endpoint =
      Trailblazer::Endpoint.build(
        domain_activity: activity,
        protocol: protocol, # do we cover all usual routes?
        adapter:  Trailblazer::Endpoint::Adapter::Web,
        scope_domain_ctx: false,
        protocol_block: -> { {Output(:not_found) => Track(:not_found)} }
    )

  # success
    assert_route(endpoint, {}, :authenticate, :policy, :model, :validate, :success)
  # authentication error
    assert_route endpoint, {authenticate: false}, :authenticate, :fail_fast           # fail_fast == protocol error
  # policy error
    assert_route endpoint, {policy: false}, :authenticate, :policy, :fail_fast        # fail_fast == protocol error
  # (domain) not_found err
    assert_route endpoint, {model: false}, :authenticate, :policy, :model, :fail_fast # fail_fast == protocol error
  # (domain) validation err
    assert_route endpoint, {validate: false}, :authenticate, :policy, :model, :validate, :failure
  end

end
