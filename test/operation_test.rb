require "test_helper"
require "trailblazer/operation"

class OperationTest < Minitest::Spec
  class Create < Trailblazer::Operation
    # step :model

    # def model(ctx, **)
    #   ctx[:model] = :object
    # end
  end

  it "returns a {Trailblazer::Context}, and only one" do
    default_matcher = {}

    matcher_block = Proc.new do
      success { |ctx, model:, **| model.inspect }
    end

    ctx = {model: Object} # ordinary hash.

    signal, ((ctx, flow_options), circuit_options) = Trailblazer::Endpoint::Runtime.(Create, ctx, default_matcher: default_matcher, matcher_context: self, &matcher_block)

    assert_equal ctx.class, Trailblazer::Context::Container
    assert_equal ctx.keys.inspect, %([:model])

    # make sure that we're not nesting two {Context} instances.
    static, mutable = ctx.decompose
    assert_equal static.class, Hash
    assert_equal mutable.class, Hash

  #@ test similar setup with aliasing.
    flow_options_with_aliasing = {
      context_options: {
        aliases: {"model": :object},
        container_class: Trailblazer::Context::Container::WithAliases,
      }
    }

    signal, ((ctx, flow_options), circuit_options) = Trailblazer::Endpoint::Runtime.(Create, ctx, default_matcher: default_matcher, matcher_context: self, flow_options: flow_options_with_aliasing, &matcher_block)

    assert_equal ctx.class, Trailblazer::Context::Container::WithAliases
    assert_equal ctx.keys.inspect, %([:model, :object])
    assert_equal ctx[:model].inspect, %(Object)
    assert_equal ctx[:object].inspect, %(Object)

    # make sure that we're not nesting two {Context} instances.
    static, mutable = ctx.decompose
    assert_equal static.class, Hash
    assert_equal mutable.class, Hash
  end
end
