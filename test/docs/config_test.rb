require "test_helper"

require "trailblazer/endpoint/options"

class ConfigTest < Minitest::Spec
  Controller = Struct.new(:params)

  it "what" do
    ApplicationController.options_for(:options_for_endpoint).inspect.must_equal %{{:find_process_model=>true, :request=>true}}

  # inherits endpoint options from ApplicationController
    ApeController.options_for(:options_for_endpoint).inspect.must_equal %{{:find_process_model=>true, :request=>true}}
  # defines its own domain options, none in ApplicationController
    ApeController.options_for(:options_for_domain_ctx).inspect.must_equal %{{:current_user=>\"Yo\"}}

    # 3-rd level, inherit everything from 2-nd level
    ApeBabeController.options_for(:options_for_endpoint).inspect.must_equal %{{:find_process_model=>true, :request=>true}}
    ApeBabeController.options_for(:options_for_domain_ctx).inspect.must_equal %{{:current_user=>\"Yo\"}}

    BoringController.options_for(:options_for_endpoint).inspect.must_equal %{{:find_process_model=>true, :request=>true, :xml=>"<XML"}}
    BoringController.options_for(:options_for_domain_ctx).inspect.must_equal %{{:policy=>\"Ehm\"}}

    OverridingController.options_for(:options_for_domain_ctx).inspect.must_equal %{{:redis=>\"Arrr\"}}
  end

  class ApplicationController
    def self.options_for_endpoint(ctx, **)
      {
        find_process_model: true,
      }
    end

    def self.request_options(ctx, **)
      {
        request: true,
      }
    end

    extend Trailblazer::Endpoint::Controller
    directive :options_for_endpoint, method(:options_for_endpoint), method(:request_options)
  end

  class ApeController < ApplicationController
    def self.options_for_domain_ctx(ctx, **)
      {
        current_user: "Yo",
      }
    end

    directive :options_for_domain_ctx, method(:options_for_domain_ctx)
  end

  class ApeBabeController < ApeController
    # def self.options_for_domain_ctx(ctx, **)
    #   {policy: "Ehm"}
    # end

    # directive :options_for_domain_ctx, method(:options_for_domain_ctx)
  end

  class BoringController < ApplicationController
    def self.options_for_domain_ctx(ctx, **) {policy: "Ehm",} end
    def self.options_for_endpoint(ctx, **)   {xml: "<XML",} end

    directive :options_for_endpoint,   method(:options_for_endpoint) #, inherit: ApplicationController
    directive :options_for_domain_ctx, method(:options_for_domain_ctx)
  end

  class OverridingController < BoringController
    def self.options_for_domain_ctx(ctx, **)
      {
        redis: "Arrr",
      }
    end
    directive :options_for_domain_ctx, method(:options_for_domain_ctx), inherit: false
  end


  it "what" do
    puts Trailblazer::Developer.render(ApplicationController.instance_variable_get(:@normalizer))
    signal, (ctx, ) = Trailblazer::Developer.wtf?( ApplicationController.instance_variable_get(:@normalizer), [{}])
    pp ctx

    ctx.inspect.must_equal %{{:options_for_endpoint=>{:find_process_model=>true}, :options_for_domain_ctx=>{}}}

    puts Trailblazer::Developer.render(MemoController.instance_variable_get(:@normalizer))
    signal, (ctx, ) = Trailblazer::Developer.wtf?( MemoController.instance_variable_get(:@normalizer), [{controller: Controller.new("bla")}])

    ctx.inspect.must_equal %{{:controller=>#<struct ConfigTest::Controller params=\"bla\">, :options_for_endpoint=>{:find_process_model=>true, :params=>\"bla\"}, :options_for_domain_ctx=>{}}}
  end

  it "does add empty hashes per class level option" do
    EmptyController.options_for_endpoint({}).must_equal({})
    EmptyController.options_for_domain_ctx({}).must_equal({})
  end

  class EmptyController < ApplicationController
    # for whatever reason, we don't override anything here.
  end

  class MemoController < EmptyController
    def self.options_for_endpoint(ctx, **)
      {
        request: "Request"
      }
    end

    def self.options_for_endpoint(ctx, controller:, **)
      {
        params: controller.params,
      }
    end
  end

  # it do
  #   MemoController.normalize_for(controller: "Controller")
  # end
end


 # # option :options_for_domain_ctx, inherit: ApplicationController



=begin
    public def compute_option(option_name)
      normalizer = self.class.instance_variable_get(:@normalizers)[option_name]

      signal, (ctx, ) = Trailblazer::Developer.wtf?( normalizer, [{option_name => {}, controller: self}])
      ctx[option_name]
    end





    def endpoint(event_name, policies,
      domain_activity: Trailblazer::Workflow::Advance::Controller,
      protocol: Charon::Endpoint::Protocol,
      scope_domain_ctx: false,
      **action_options, # [:process_model_id, :find_process_model] passed from the user.
      &block)


      default_build_options = {
        adapter:          Charon::Endpoint::Adapter,
        protocol:         protocol,
        domain_activity:  domain_activity,
        scope_domain_ctx: scope_domain_ctx,
        domain_ctx_filter: Charon::Endpoint.current_user_in_domain_ctx,
      }

      build_and_invoke_endpoint(event_name, policies, default_build_options: default_build_options, **action_options, &block)
    end

    def build_and_invoke_endpoint(event_name, policies, default_build_options:, **action_options, &block)
# FIXME: make at compile-time
      _, endpoint = Trailblazer::Endpoint::Builder::DSL.endpoint_for(id: event_name, builder: Charon::Endpoint::Builder, default_options: default_build_options, policies: policies, with_root: true)

      invoke_endpoint(endpoint, event_name, **action_options, &block)
    end


    # Controller-specific!
    # Merge various controller options hashes, etc.
    def invoke_endpoint(endpoint, event_name, options_for_domain_ctx: self.compute_option(:options_for_domain_ctx), **action_options, &block)
      domain_ctx = options_for_domain_ctx

      position = ApplicationController.advance_ep(
        endpoint,
        event_name: event_name,

        domain_ctx: domain_ctx,

        success_block:    self.success_block, # the blocks need to be defined in controller instance context.
        failure_block:    self.failure_block,
        protocol_failure_block: self.protocol_failure_block,

        controller_block: block, # DISCUSS: do we always need that?

        **self.compute_option(:options_for_endpoint), # "class level"
        **action_options,     # per action
      )

      return position
    end

    class Or
      def initialize(execute:, ctx: nil)
        @execute = execute
        @ctx     = ctx
      end

      def Or(&block)
        yield(@ctx) if @execute
      end
    end
  end

  include Endpoint
    public def compute_option(option_name)
      normalizer = self.class.instance_variable_get(:@normalizers)[option_name]

      signal, (ctx, ) = Trailblazer::Developer.wtf?( normalizer, [{option_name => {}, controller: self}])
      ctx[option_name]
    end

  @normalizers= {
    options_for_domain_ctx: Trailblazer::Endpoint::Normalizer___({
      ApplicationController::Endpoint.method(:options_for_domain_ctx) => :options_for_domain_ctx,
      ApplicationController::Endpoint.method(:redis_options) => :options_for_domain_ctx
    }
    ),
    options_for_endpoint: Trailblazer::Endpoint::Normalizer___({
      ApplicationController::Endpoint.method(:options_for_endpoint) => :options_for_endpoint,
    }
    )
  }



  def legacy_operation(operation, policies, &block)
   default_build_options = {
      adapter:          Charon::Endpoint::Adapter,
      domain_ctx_filter: Charon::Endpoint.current_user_in_domain_ctx,
      domain_activity: operation,
      protocol: Charon::Endpoint::Protocol::LegacyOperation,
      scope_domain_ctx: true
    }

    _, endpoint = Trailblazer::Endpoint::Builder::DSL.endpoint_for(id: operation, builder: Charon::Endpoint::Builder, default_options: default_build_options, policies: policies, with_root: true)
# TODO: build on class level

    invoke_endpoint(endpoint, operation, &block)
  end


  def self.advance_ep(endpoint, success_block:, failure_block:, protocol_failure_block:, **argument_options)
    args, _ = Trailblazer::Endpoint.arguments_for(Charon::Endpoint.arguments_for(argument_options))

    signal, (ctx, _ ) = Trailblazer::Endpoint.with_or_etc(
      endpoint,
      args, # [ctx, flow_options]

      success_block: success_block,
      failure_block: failure_block,
      protocol_failure_block: protocol_failure_block,
    )

    return ctx[:__or__]
  end

=end
