require "test_helper"

require "trailblazer/endpoint/options"

class ConfigTest < Minitest::Spec
  Controller = Struct.new(:params)

  it "what" do
    ApplicationController.options_for(:options_for_endpoint, {}).inspect.must_equal %{{:find_process_model=>true, :request=>true}}

  # inherits endpoint options from ApplicationController
    ApeController.options_for(:options_for_endpoint, {}).inspect.must_equal %{{:find_process_model=>true, :request=>true}}
  # defines its own domain options, none in ApplicationController
    ApeController.options_for(:options_for_domain_ctx, {}).inspect.must_equal %{{:current_user=>\"Yo\"}}

    # 3-rd level, inherit everything from 2-nd level
    ApeBabeController.options_for(:options_for_endpoint, {}).inspect.must_equal %{{:find_process_model=>true, :request=>true}}
    ApeBabeController.options_for(:options_for_domain_ctx, {}).inspect.must_equal %{{:current_user=>\"Yo\"}}

    BoringController.options_for(:options_for_endpoint, {}).inspect.must_equal %{{:find_process_model=>true, :request=>true, :xml=>"<XML"}}
    BoringController.options_for(:options_for_domain_ctx, {}).inspect.must_equal %{{:policy=>\"Ehm\"}}

    OverridingController.options_for(:options_for_domain_ctx, {}).inspect.must_equal %{{:redis=>\"Arrr\"}}
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
end

class RuntimeOptionsTest < Minitest::Spec
  class ApplicationController
    def self.options_for_endpoint(ctx, controller:, **)
      {
        option: true,
        params: controller[:params],
      }
    end

  # You can access variables set prior to this options directive.
    def self.request_options(ctx, controller:, params:, **)
      {
        my_params: params.inspect,
        option: nil,
      }
    end

    extend Trailblazer::Endpoint::Controller
    directive :options_for_endpoint, method(:options_for_endpoint), method(:request_options)
  end

  it do
    ApplicationController.options_for(:options_for_endpoint, controller: {params: {id: 1}}).inspect.must_equal %{{:option=>nil, :params=>{:id=>1}, :my_params=>\"{:id=>1}\"}}
  end
end
