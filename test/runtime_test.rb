require "test_helper"

# This tests {Runtime.call}, the top-level entry point for end users.
class RuntimeTest < Minitest::Spec
  class Create < Trailblazer::Activity::FastTrack
    include T.def_steps(:model)

    step :model
  end

  def render(content)
    @render = content
  end

  let(:ctx) { {seq: [], model: Object} }

  it "without block, accepts operation and {ctx}, and returns original returnset" do
    signal, (result, _) = Trailblazer::Endpoint::Runtime.(Create, ctx)

    assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
    assert_equal result.class, Trailblazer::Context::Container
    assert_equal CU.inspect(result.to_h), %({:seq=>[:model], :model=>Object})
  end

  it "it accepts {:flow_options}" do
    flow_options_with_aliasing = {
      context_options: {
        aliases: {"model": :record},
        container_class: Trailblazer::Context::Container::WithAliases,
      }
    }

    signal, (result, _) = Trailblazer::Endpoint::Runtime.(Create, ctx, flow_options: flow_options_with_aliasing)

    assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
    assert_equal result.class, Trailblazer::Context::Container::WithAliases
    assert_equal CU.inspect(result.to_h), %({:seq=>[:model], :model=>Object, :record=>Object})
    assert_equal result[:record], Object
  end

  it "accepts {:default_matcher}" do # DISCUSS: we don't need the explicit block in this case.
    default_matcher = {
      success:    ->(ctx, model:, **) { render "201, #{model}" },
      not_found:  ->(ctx, model:, **) { render "404, #{model} not found" },
      not_authorized: ->(*) { snippet },
    }

    signal, (result, _) = Trailblazer::Endpoint::Runtime.(Create, ctx, matcher_context: self, default_matcher: default_matcher) do
    end

    assert_equal @render, %(201, Object)
  end

  it "accepts a block" do
    signal, (result, _) = Trailblazer::Endpoint::Runtime.(Create, ctx, matcher_context: self) do
      success { |ctx, model:, **| render model.inspect }
    end

    assert_equal signal.inspect, %(#<Trailblazer::Activity::End semantic=:success>)
    assert_equal result.class, Trailblazer::Context::Container
    assert_equal CU.inspect(result.to_h), %({:seq=>[:model], :model=>Object})
    assert_equal @render, %(Object)
  end


  it "Activity can be invoked via {TopLevel#__()}" do
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

    signal, (ctx,) = kernel.new.__(Create, self.ctx) # FLOW_OPTIONS are applied!

    assert_equal ctx[:record], Object

    stdout, _ = capture_io do
      signal, (ctx,) = kernel.new.__?(Create, self.ctx) # FLOW_OPTIONS are applied!
    end

    assert_equal ctx[:record], Object
    assert_equal stdout, %(RuntimeTest::Create
|-- \e[32mStart.default\e[0m
|-- \e[32mmodel\e[0m
`-- End.success
)
  end




  # FIXME: what is this test?
  it "using {Runtime::Matcher.call} without a Protocol" do
    ctx = {seq: [], model: Object}

    Trailblazer::Endpoint::Runtime::Matcher.(Create, ctx, default_matcher: {}, matcher_context: self) do
      success { |ctx, model:, **| render model.inspect }
    end

    assert_equal @render, %(Object)
  end
end

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

  it "{Runtime::Matcher.call} matcher block" do
    default_matcher = {
      success:    ->(*) { raise },
      not_found:  ->(ctx, model:, **) { render "404, #{model} not found" },
      not_authorized: ->(*) { snippet },
    }

    action_protocol = Trailblazer::Endpoint.build(protocol: Protocol, domain_activity: Create, protocol_block: ->(*) { {Output(:not_found) => Track(:not_found)} })
    # action_adapter  = Trailblazer::Endpoint::Adapter.build(action_protocol) # build the simplest Adapter we got.

    # this is usually in a controller action.
    matcher_block = Proc.new do
      success { |ctx, model:, **| render model.inspect }
      failure { |*| render "failure" }
      not_authorized { |ctx, model:, **| render "not authorized: #{model}" }
    end

    ctx = {seq: [], model: {id: 1}}

    Trailblazer::Endpoint::Runtime::Matcher.(action_protocol, ctx, default_matcher: default_matcher, matcher_context: self, &matcher_block)
    assert_equal @rendered, %(Object)

    ctx = {seq: [], model: {id: 1}}

    Trailblazer::Endpoint::Runtime::Matcher.(action_protocol, ctx.merge(model: false), default_matcher: default_matcher, matcher_context: self, &matcher_block)
    assert_equal @rendered, %(404, false not found)

    ctx = {seq: [], model: {id: 1}}

    Trailblazer::Endpoint::Runtime::Matcher.(action_protocol, ctx.merge(save: false), default_matcher: default_matcher, matcher_context: self, &matcher_block)
    assert_equal @rendered, %(failure)

    ctx = {seq: [], model: {id: 1}}

    Trailblazer::Endpoint::Runtime::Matcher.(action_protocol, ctx.merge(policy: false), default_matcher: default_matcher, matcher_context: self, &matcher_block)
    assert_equal @rendered, %(not authorized: {:id=>1})

    ctx = {seq: [], model: {id: 1}}

    assert_raises KeyError do
      Trailblazer::Endpoint::Runtime::Matcher.(action_protocol, ctx.merge(authenticate: false), default_matcher: default_matcher, matcher_context: self, &matcher_block)
      # assert_equal @rendered, %(404, false not found)
    end

    # endpoint "bla", ctx: {} do
    #   success do |ctx, model:, **|
    #     render model.inspect
    #   end
    # end

    # run "bla", ctx: {} do
    #   render model.inspect
    # end

    # Trailblazer::Endpoint::Runtime::Matcher.call ctx, adapter: action_adapter do
    #   success { |ctx, model:, **| render model.inspect }
    #   failure { |*| render "failure" }
    #   not_authorized { |ctx, model:, **| render "not authorized: #{model}" }
    # end
  end

  it "returns a {Trailblazer::Context}, and allows {flow_options}" do
    default_matcher = {}

    action_protocol = Trailblazer::Endpoint.build(protocol: Protocol, domain_activity: Create)
    # action_adapter  = Trailblazer::Endpoint::Adapter.build(action_protocol) # build the simplest Adapter we got.

    matcher_block = Proc.new do
      success { |ctx, model:, **| render model.inspect }
    end

    ctx = {seq: [], model: {id: 1}} # ordinary hash.

    flow_options_with_aliasing = {
      context_options: {
        aliases: {"model": :object},
        container_class: Trailblazer::Context::Container::WithAliases,
      }
    }

    signal, ((ctx, flow_options), circuit_options) = Trailblazer::Endpoint::Runtime::Matcher.(action_protocol, ctx, default_matcher: default_matcher, matcher_context: self, flow_options: flow_options_with_aliasing, &matcher_block)

    assert_equal ctx.class, Trailblazer::Context::Container::WithAliases
    # assert_equal ctx.inspect, %(#<Trailblazer::Context::Container wrapped_options={:seq=>[:authenticate, :policy, :save], :model=>{:id=>1}} mutable_options={:model=>Object}>)
    assert_equal ctx.keys.inspect, %([:seq, :model, :object])
    assert_equal ctx[:seq].inspect, %([:authenticate, :policy, :save])
    assert_equal ctx[:model].inspect, %(Object)
    assert_equal ctx[:object].inspect, %(Object)
  end

  it "accepts {:flow_options} / USES  THE CORRECT ctx in TW and can access {:model} from the domain_activity" do # FIXME: two tests?
    protocol = Class.new(Trailblazer::Activity::Railway) do
      step task: :save
      terminus :not_found
      terminus :not_authenticated
      terminus :not_authorized

      def save((ctx, flow_options), **)
        ctx = ctx.merge(model: flow_options[:model])
        return Trailblazer::Activity::Right, [ctx, flow_options]
      end
    end

    # this is usually in a controller action.
    matcher_block = Proc.new do
      success { |ctx, model:, **| render model.inspect }
    end

    default_matcher = {}
    # adapter  = Trailblazer::Endpoint::Adapter.build(protocol)

    # ctx doesn't contain {:model}, yet.
    Trailblazer::Endpoint::Runtime::Matcher.(protocol,  {}, flow_options: {model: Object}, default_matcher: default_matcher, matcher_context: self, &matcher_block)
    assert_equal @rendered, %(Object)
  end

  it "Matcher.() allows other keyword arguments such as {:invoke_method}" do
    # this is usually in a controller action.
    matcher_block = Proc.new do
      success { |ctx, model:, **| render model.inspect }
    end

    default_matcher = {}
    # adapter  = Trailblazer::Endpoint::Adapter.build(protocol)

    # ctx doesn't contain {:model}, yet.
    stdout, _ = capture_io do
      Trailblazer::Endpoint::Runtime::Matcher.(Create, {seq: []}, invoke_method: Trailblazer::Developer::Wtf.method(:invoke), default_matcher: default_matcher, matcher_context: self, &matcher_block)
    end

    assert_equal @rendered, %(Object)
    assert_equal stdout, %(ProtocolTest::Create
|-- \e[32mStart.default\e[0m
|-- \e[32mmodel\e[0m
|-- \e[32msave\e[0m
`-- End.success
)
  end

  it "PROTOTYPING canonical invoke" do
    # decisions = {
    #   ->(activity, ctx) {  }
    # }
    # decisions = Trace::Decision.new(decisions)


    # MY_TRACE_GUARDS = ->(activity, ctx) do

    # end


    my_dynamic_arguments = ->(activity, options) {
      invoke_method_option = [Create].include?(activity) ? {invoke_method: Trailblazer::Developer::Wtf.method(:invoke)} : {}

      present_options_option = {}

      {
        **invoke_method_option,
        **present_options_option, # TODO: test if this is working.
      }
    }

    matcher_block = Proc.new do
      success { |ctx, model:, **| render model.inspect }
    end

    default_matcher = {}

    stdout, _ = capture_io do
      Trailblazer::Endpoint::Runtime.(
        activity = Create, options = {seq: []},
        flow_options: {bla: 1}, # DISCUSS: from dynamic, too?
        **my_dynamic_arguments.(activity, options), # represents {:invoke_method} and {:present_options}
        default_matcher: default_matcher, matcher_context: self, &matcher_block
      )
    end

    assert_equal @rendered, %(Object)
    assert_equal stdout, %(ProtocolTest::Create
|-- \e[32mStart.default\e[0m
|-- \e[32mmodel\e[0m
|-- \e[32msave\e[0m
`-- End.success
)

    # Test that the "decider" for {:invoke_method} really works.
    update_operation = Class.new(Trailblazer::Activity::Railway)

    stdout, _ = capture_io do
      Trailblazer::Endpoint::Runtime.(
        activity = update_operation, options = {model: "Yes!"},
        flow_options: {bla: 1}, # DISCUSS: from dynamic, too?
        **my_dynamic_arguments.(activity, options), # represents {:invoke_method} and {:present_options}
        default_matcher: default_matcher, matcher_context: self, &matcher_block
      )
    end

    assert_equal @rendered, %("Yes!")
    assert_equal stdout, ""
  end
end
