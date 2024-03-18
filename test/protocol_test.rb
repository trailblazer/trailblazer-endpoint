require "test_helper"

class ProtocolTest < Minitest::Spec
  def render(text)
    @rendered = text
  end

  class Create < Trailblazer::Activity::Railway
    include T.def_steps(:model, :validate, :save, :cc_check)

    def model(ctx, model: true, **)
      return unless model
      ctx[:model] = Object
    end

    step :model,    Output(:failure) => End(:not_found)
    # step :cc_check, Output(:failure) => End(:cc_invalid)
    # step :validate, Output(:failure) => End(:my_validation_error)
    step :save
  end

  class Protocol < Trailblazer::Endpoint::Protocol
    include T.def_steps(:authenticate, :policy)
  end

  it "what" do
    default_matcher = Trailblazer::Endpoint::Matcher.new(
      success:    ->(*) { raise },
      not_found:  ->(ctx, model:, **) { render "404, #{model} not found" },
      not_authorized: ->(*) { snippet },
    )

    matcher = Trailblazer::Endpoint::Matcher::DSL.new

    matcher.success do |ctx, model:, **|
      render model.inspect
    end.failure do |*|
      render "failure"
    end.not_authorized do |ctx, model:, **|
      render "not authorized: #{model}"
    end

    matcher_value = Trailblazer::Endpoint::Matcher::Value.new(default_matcher, matcher, self)

    action_protocol = Trailblazer::Endpoint.build_protocol(Protocol, domain_activity: Create, protocol_block: ->(*) { {Output(:not_found) => Track(:not_found)} })

    action_adapter = Trailblazer::Endpoint::Adapter.build(action_protocol) # build the simplest Adapter we got.

    ctx = {seq: [], model: {id: 1}}

    Trailblazer::Developer.wtf?(action_adapter, [ctx, {matcher_value: matcher_value}])
    assert_equal @rendered, %(Object)

    Trailblazer::Developer.wtf?(action_adapter, [ctx.merge(model: false), {matcher_value: matcher_value}])
    assert_equal @rendered, %(404, false not found)

    Trailblazer::Developer.wtf?(action_adapter, [ctx.merge(save: false), {matcher_value: matcher_value}])
    assert_equal @rendered, %(failure)

    Trailblazer::Developer.wtf?(action_adapter, [ctx.merge(policy: false), {matcher_value: matcher_value}])
    assert_equal @rendered, %(not authorized: Object)

    assert_raises KeyError do
      Trailblazer::Developer.wtf?(action_adapter, [ctx.merge(authenticate: false), {matcher_value: matcher_value}])
      # assert_equal @rendered, %(404, false not found)
    end
  end
end
