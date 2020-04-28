require "test_helper"

class ProtocolTest < Minitest::Spec

  class CreatePrototypeProtocol < Trailblazer::Endpoint::Protocol

    include EndpointTest::T.def_steps(:authenticate, :handle_not_authenticated, :policy, :handle_not_authorized, :handle_not_found)

    # Here, we test a domain OP with ADDITIONAL explicit ends that get wired to the Adapter (vaidation_error => failure).
    # We still need to test the other way round: wiring a "normal" failure to, say, not_found, by inspecting the ctx.
    step Subprocess(Create), # we have S/F/NF/VE outputs
      replace: :domain_activity,
      id: :domain_activity,  # DISCUSS: do we want to repeat the ID?
      Output(:my_validation_error) => Track(:failure),
      Output(:not_found) => _Path(semantic: :not_found) do
        step :handle_not_found # FIXME: don't require steps in path!
        # DISCUSS: are we actually overriding anything, here?
      end


    # success
    # failure
    # not_authenticated
    # not_authorized
    # not_found
    # my_validation_error => failure
  end

   it "what" do
    puts Trailblazer::Developer.render(CreatePrototypeProtocol)



# 1. authenticate works
    ctx = {seq: []}
    signal, (ctx, _ ) = Trailblazer::Developer.wtf?(CreatePrototypeProtocol, [ctx, {}])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :cc_check, :validate, :save]}

# 1. authenticate err
    ctx = {seq: [], authenticate: false}
    signal, (ctx, _ ) = Trailblazer::Developer.wtf?(CreatePrototypeProtocol, [ctx, {}])

    signal.inspect.must_equal %{#<Trailblazer::Endpoint::Protocol::Failure semantic=:not_authenticated>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :handle_not_authenticated]}

# 2. model err 404
    ctx = {seq: [], model: false}
    signal, (ctx, _ ) = Trailblazer::Developer.wtf?(CreatePrototypeProtocol, [ctx, {}])

    signal.inspect.must_equal %{#<Trailblazer::Endpoint::Protocol::Failure semantic=:not_found>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :handle_not_found]}

# 3. validation err
    ctx = {seq: [], validate: false}
    signal, (ctx, _ ) = Trailblazer::Developer.wtf?(CreatePrototypeProtocol, [ctx, {}])

  # rewired to standard failure
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :cc_check, :validate]}

end
