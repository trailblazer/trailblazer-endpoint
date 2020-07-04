require "test_helper"

class DocsAPITest < Minitest::Spec
  def activity
    activity = Class.new(Trailblazer::Activity::Railway) do
      step :model, Output(:failure) => End(:not_found)
      step :validate

      include T.def_steps(:validate, :model)
    end
  end

  it "Adapter::API" do
    protocol = Class.new(Trailblazer::Endpoint::Protocol) do # DISCUSS: what to to with authenticate and policy?
      include T.def_steps(:authenticate, :policy)
    end

    endpoint =
      Trailblazer::Endpoint.build(
        domain_activity: activity,
        protocol: protocol, # do we cover all usual routes?
        adapter:  Trailblazer::Endpoint::Adapter::API,
        scope_domain_ctx: false,
    ) do


      {Output(:not_found) => Track(:not_found)}
    end

  # success
    assert_route endpoint, {}, :authenticate, :policy, :model, :validate, :success, status: 200
  # authentication error
    assert_route endpoint, {authenticate: false}, :authenticate, :fail_fast, status: 401           # fail_fast == protocol error
  # policy error
    assert_route endpoint, {policy: false}, :authenticate, :policy, :fail_fast, status: 403        # fail_fast == protocol error
  # (domain) not_found err
    assert_route endpoint, {model: false}, :authenticate, :policy, :model, :fail_fast, status: 404 # fail_fast == protocol error
  # (domain) validation err
    assert_route endpoint, {validate: false}, :authenticate, :policy, :model, :validate, :failure, status: 422
  end
end
