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

    signal, ((ctx, flow_options), circuit_options) = Trailblazer::Endpoint::Runtime::Matcher.(Create, ctx, default_matcher: default_matcher, matcher_context: self, &matcher_block)

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

    signal, ((ctx, flow_options), circuit_options) = Trailblazer::Endpoint::Runtime::Matcher.(Create, ctx, default_matcher: default_matcher, matcher_context: self, flow_options: flow_options_with_aliasing, &matcher_block)

    assert_equal ctx.class, Trailblazer::Context::Container::WithAliases
    assert_equal ctx.keys.inspect, %([:model, :object])
    assert_equal ctx[:model].inspect, %(Object)
    assert_equal ctx[:object].inspect, %(Object)

    # make sure that we're not nesting two {Context} instances.
    static, mutable = ctx.decompose
    assert_equal static.class, Hash
    assert_equal mutable.class, Hash
  end

  it "Operation can be invoked via {TopLevel#__()}" do
    create = Class.new(Trailblazer::Operation) do
      include T.def_steps(:model)
      step :model
    end

    kernel = Class.new do
      include Trailblazer::Endpoint::Runtime::TopLevel

      def __(operation, ctx, flow_options: FLOW_OPTIONS, **, &block)
        super
      end

      FLOW_OPTIONS = {
        context_options: {
          aliases: {"model": :record},
          container_class: Trailblazer::Context::Container::WithAliases,
        }
      }
    end

    ctx = {seq: [], model: Object}

    signal, (ctx,) = kernel.new.__(create, ctx) # FLOW_OPTIONS are applied!

    assert_equal signal.inspect, %(#<Trailblazer::Activity::Railway::End::Success semantic=:success>)
    assert_equal ctx[:record], Object

    stdout, _ = capture_io do
      signal, (ctx,) = kernel.new.__?(create, ctx) # FLOW_OPTIONS are applied!
    end

    assert_equal ctx[:record], Object

    stdout = stdout.sub(/0x\w+/, "XXX")

    assert_equal stdout, %(#<Class:XXX>
|-- \e[32mStart.default\e[0m
|-- \e[32mmodel\e[0m
`-- End.success
)
  end
end
