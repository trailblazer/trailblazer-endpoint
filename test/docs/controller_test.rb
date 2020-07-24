require "test_helper"

class DocsControllerTest < Minitest::Spec
  protocol = Class.new(Trailblazer::Endpoint::Protocol)do
    include T.def_steps(:authenticate, :policy)
  end

  endpoint =
    Trailblazer::Endpoint.build(
      domain_activity: activity,
      protocol: protocol,
      adapter: Trailblazer::Endpoint::Adapter::Web,
      scope_domain_ctx: false,

  ) do
    {Output(:not_found) => Track(:not_found)}
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


  class HtmlController < ApplicationController

    def view
      endpoint "view?",
    end

  end
end

require "trailblazer/endpoint/controller"
class ControllerOptionsTest < Minitest::Spec
  class Controller
    include Trailblazer::Endpoint::Controller

    def view
      endpoint "view?"
    end

    # we add {:options_for_domain_ctx} manually
    def download
      endpoint "download?", params: {id: params[:other_id]}, redis: "Redis"
    end

    # override some settings from {endpoint_options}:
    def new
      endpoint "new?", find_process_model: false
    end
  end

  class ControllerThatDoesntInherit
    include Trailblazer::Endpoint::Controller

    def options_for_domain_ctx
      {
        params: params
      }
    end

    def options_for_endpoint

    end

    def view
      endpoint "view?"
    end

    # we add {:options_for_domain_ctx} manually
    def download
      endpoint "download?", params: {id: params[:other_id]}, redis: "Redis"
    end

    # override some settings from {endpoint_options}:
    def new
      endpoint "new?", find_process_model: false
    end
  end

  it "what" do

  end

  it "allows to get options without a bloody controller" do
    MemoController.bla(params: params)
  end
end


class DocsControllerTest < Minitest::Spec
  it "what" do
    endpoint "view?" do |ctx|
      # 200, success
      return
    end

    # 422
    # but also 404 etc
  end


  class Controller
    def initialize(endpoint, activity)
      @___activity = activity
      @endpoint = endpoint
      @seq      = []
    end

    def view(params)
      endpoint "view?", params do |ctx|
        @seq << :success
        # 200, success
        return
      end.Or() do |ctx|
        # Only 422
        @seq << :failure
      end
    end

    def call(action, **params)
      send(action, **params)
      @seq
    end

    private def endpoint(action, params, &block)
      ctx = Trailblazer::Endpoint.advance_from_controller(@endpoint,
        event_name:             "",
        success_block: block,
        failure_block: ->(*) { return },
        protocol_failure_block: ->(*) { @seq << 401 and return },

        domain_ctx: {},
        flow_options: {},

        **params,

      # DISCUSS: do we really like that fuzzy API? if yes, why do we need {additional_endpoint_options} or whatever it's called?
        seq: @seq,

        or_status: [422, :failure]
      )
    end
  end

  it "injected {return} interrupts the controller action" do
    protocol = Class.new(Trailblazer::Endpoint::Protocol)do
      include T.def_steps(:authenticate, :policy)
    end

    endpoint =
      Trailblazer::Endpoint.build(
        domain_activity: activity,
        protocol: protocol,
        adapter: Trailblazer::Endpoint::Adapter::Web,
        scope_domain_ctx: false,

    ) do
      {Output(:not_found) => Track(:not_found)}
    end

  # 200
    seq = Controller.new(endpoint, activity).call(:view)
    seq.must_equal [:authenticate, :policy, :model, :validate, :success] # the {return} works.

  # 401
    seq = Controller.new(endpoint, activity).call(:view, authenticate: false)
    seq.must_equal [:authenticate, 401]
  end
end
