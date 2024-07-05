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

  it "{Runtime.call}" do
    default_matcher = {
      success:    ->(*) { raise },
      not_found:  ->(ctx, model:, **) { render "404, #{model} not found" },
      not_authorized: ->(*) { snippet },
    }

    action_protocol = Trailblazer::Endpoint.build_protocol(protocol: Protocol, domain_activity: Create, protocol_block: ->(*) { {Output(:not_found) => Track(:not_found)} })
    action_adapter  = Trailblazer::Endpoint::Adapter.build(action_protocol) # build the simplest Adapter we got.

    # this is usually in a controller action.
    matcher_block = Proc.new do
      success { |ctx, model:, **| render model.inspect }
      failure { |*| render "failure" }
      not_authorized { |ctx, model:, **| render "not authorized: #{model}" }
    end

    ctx = {seq: [], model: {id: 1}}

    Trailblazer::Endpoint::Runtime.(ctx, adapter: action_adapter, default_matcher: default_matcher, matcher_context: self, &matcher_block)
    assert_equal @rendered, %(Object)

    Trailblazer::Endpoint::Runtime.(ctx.merge(model: false), adapter: action_adapter, default_matcher: default_matcher, matcher_context: self, &matcher_block)
    assert_equal @rendered, %(404, false not found)

    Trailblazer::Endpoint::Runtime.(ctx.merge(save: false), adapter: action_adapter, default_matcher: default_matcher, matcher_context: self, &matcher_block)
    assert_equal @rendered, %(failure)

    Trailblazer::Endpoint::Runtime.(ctx.merge(policy: false), adapter: action_adapter, default_matcher: default_matcher, matcher_context: self, &matcher_block)
    assert_equal @rendered, %(not authorized: Object)

    assert_raises KeyError do
      Trailblazer::Endpoint::Runtime.(ctx.merge(authenticate: false), adapter: action_adapter, default_matcher: default_matcher, matcher_context: self, &matcher_block)
      # assert_equal @rendered, %(404, false not found)
    end

    #,mljnimh

    # endpoint "bla", ctx: {} do
    #   success do |ctx, model:, **|
    #     render model.inspect
    #   end
    # end

    # run "bla", ctx: {} do
    #   render model.inspect
    # end

    # Trailblazer::Endpoint::Runtime.call ctx, adapter: action_adapter do
    #   success { |ctx, model:, **| render model.inspect }
    #   failure { |*| render "failure" }
    #   not_authorized { |ctx, model:, **| render "not authorized: #{model}" }
    # end
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
    adapter  = Trailblazer::Endpoint::Adapter.build(protocol)

    # ctx doesn't contain {:model}, yet.
    Trailblazer::Endpoint::Runtime.({}, flow_options: {model: Object}, adapter: adapter, default_matcher: default_matcher, matcher_context: self, &matcher_block)
    assert_equal @rendered, %(Object)
  end
end
