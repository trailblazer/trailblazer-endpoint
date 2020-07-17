require "test_helper"

require "trailblazer/endpoint/options"

class ConfigTest < Minitest::Spec
  Controller = Struct.new(:params)

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

    @normalizer = Trailblazer::Endpoint.Normalizer___(ApplicationController.method(:options_for_endpoint) => :options_for_endpoint, ApplicationController.method(:request_options)=> :options_for_endpoint )


    #extend Trailblazer::Endpoint.Normalizer(target: self, methods: [:options_for_endpoint, :options_for_domain_ctx])
  end

  it "what" do
    signal, (ctx, ) = Trailblazer::Developer.wtf?( ApplicationController.instance_variable_get(:@normalizer), [{options_for_endpoint: {}}])

    ctx.inspect.must_equal %{{:options_for_endpoint=>{:find_process_model=>true, :request=>true}}}
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
