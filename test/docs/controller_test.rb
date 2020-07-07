require "test_helper"

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
      end

      @seq << :failure
      # 422
      # but also 404 etc
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

        collaboration: @___activity,
        domain_ctx: {},
        success_id: "fixme",
        flow_options: {},

        **params,

      # DISCUSS: do we really like that fuzzy API? if yes, why do we need {additional_endpoint_options} or whatever it's called?
        seq: @seq,
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
    seq.must_equal [:authenticate, :policy, :model, :validate, :success]
  end

  it "what" do
    endpoint "view?" do |ctx|
      # 200, success
      return
    end.Or() do |ctx|
      # Only 422
    end
  end
end
