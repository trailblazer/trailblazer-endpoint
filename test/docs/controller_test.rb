require "test_helper"

class DocsControllerTest < Minitest::Spec

  class ApplicationController
    def self.options_for_endpoint(ctx, controller:, **)
      {
        find_process_model: true,
        **controller.instance_variable_get(:@params)[:params],
      }
    end

    def self.request_options(ctx, **)
      {
        request: true,
      }
    end

    def self.options_for_flow_options(ctx, **)
      {
      }
    end

    def self.options_for_block_options(ctx, controller:, **)
      {
        success_block:          ->(ctx, seq:, **) { controller.instance_exec { render seq << :success_block } },
        failure_block:          ->(ctx, seq:, **) { controller.instance_exec { render seq << :failure_block } },
        protocol_failure_block: ->(ctx, seq:, **) { controller.instance_exec { render seq << :protocol_failure_block } }
      }
    end


    extend Trailblazer::Endpoint::Controller
    directive :options_for_endpoint, method(:options_for_endpoint), method(:request_options)
    directive :options_for_flow_options, method(:options_for_flow_options)
    directive :options_for_block_options, method(:options_for_block_options)

    def process(action_name, **params)
      @params = params
      send_action(action_name)
      @render
    end

    def render(text)
      @render = text
    end

    include Trailblazer::Endpoint::Controller # FIXME
    include Trailblazer::Endpoint::Controller::Rails
    include Trailblazer::Endpoint::Controller::Rails::Process



    protocol = Class.new(Trailblazer::Endpoint::Protocol) do
      include T.def_steps(:authenticate, :policy)
    end

    endpoint protocol: protocol, adapter: Trailblazer::Endpoint::Adapter::Web, domain_ctx_filter: Trailblazer::Endpoint.domain_ctx_filter([:current_user, :process_model]), scope_domain_ctx: true
  end

  class HtmlController < ApplicationController
    private def endpoint_for(*)
      protocol = Class.new(Trailblazer::Endpoint::Protocol) do
        include T.def_steps(:authenticate, :policy)
      end

      endpoint =
        Trailblazer::Endpoint.build(
          domain_activity: Minitest::Spec.new(nil).activity, # FIXME
          protocol: protocol,
          adapter: Trailblazer::Endpoint::Adapter::Web,
          scope_domain_ctx: true,

      ) do
        {Output(:not_found) => Track(:not_found)}
      end
    end

    def self.options_for_domain_ctx(ctx, seq:, controller:, **)
      {
        current_user: "Yo",
        seq: seq,
        **controller.instance_variable_get(:@params)[:params],
      }
    end

    directive :options_for_domain_ctx, method(:options_for_domain_ctx)

    private def _endpoint(action, seq: [], &block)
      endpoint(action, seq: seq, &block)
    end

    # all standard routes are user-defined
    def view
      _endpoint "view?" do |ctx, seq:, **|
        render "success" + ctx[:current_user] + seq.inspect
      end.failure do |ctx, seq:, **|
        render "failure" + ctx[:current_user] + seq.inspect

      end.protocol_failure do |ctx, seq:, **|
        render "protocol_failure" + ctx[:current_user] + seq.inspect
      end
    end

    # standard use-case: only success
    def show
      _endpoint "view?" do |ctx, seq:, **|
        render "success" + ctx[:current_user] + seq.inspect
      end
    end

    # standard use case: {success} and {failure}
    def update
      _endpoint "view?" do |ctx, seq:, **|
        render "success" + ctx[:current_user] + seq.inspect
      end.Or do |ctx, seq:, **|
        render "Fail!" + ctx[:current_user] + seq.inspect
      end
    end

  end # HtmlController

  it "what" do
  # success
    controller = HtmlController.new
    controller.process(:view, params: {}).must_equal %{successYo[:authenticate, :policy, :model, :validate]}

  # failure
    controller = HtmlController.new
    controller.process(:view, params: {validate: false}).must_equal %{failureYo[:authenticate, :policy, :model, :validate]}

  # protocol_failure
    controller = HtmlController.new
    controller.process(:view, params: {authenticate: false}).must_equal %{protocol_failureYo[:authenticate]}
  end

  it "only success_block is user-defined" do
  # success
    controller = HtmlController.new
    controller.process(:show, params: {}).must_equal %{successYo[:authenticate, :policy, :model, :validate]}

  # failure
    controller = HtmlController.new
    # from controller-default
    controller.process(:show, params: {validate: false}).must_equal [:authenticate, :policy, :model, :validate, :failure_block]

  # protocol_failure
    controller = HtmlController.new
    # from controller-default
    controller.process(:show, params: {authenticate: false}).must_equal [:authenticate, :protocol_failure_block]
  end

  it "success/Or" do
  # success
    controller = HtmlController.new
    controller.process(:update, params: {}).must_equal %{successYo[:authenticate, :policy, :model, :validate]}

  # failure
    controller = HtmlController.new
    # from controller-default
    controller.process(:update, params: {validate: false}).must_equal %{Fail!Yo[:authenticate, :policy, :model, :validate]}

  # protocol_failure
    controller = HtmlController.new
    # from controller-default
    controller.process(:update, params: {authenticate: false}).must_equal [:authenticate, :protocol_failure_block]
  end


# Test if {domain_ctx} is automatically wrapped via Context() so that we can use string-keys.
# TODO: test if aliases etc are properly passed.
  class OptionsController < HtmlController
    def self.options_for_domain_ctx(ctx, seq:, controller:, **)
      {
        "contract.params" => Object, # string-key should usually break if not wrapped
      }
    end

    def self.options_for_endpoint(ctx, controller:, **)
      {
        current_user: "Yogi",
        process_model: Class,
      }
    end

    directive :options_for_domain_ctx, method(:options_for_domain_ctx)
    directive :options_for_endpoint, method(:options_for_endpoint), inherit: false

    def view
      _endpoint "view?" do |ctx, seq:, **|
        render "success" + ctx["contract.params"].to_s + seq.inspect
      end
    end
  end # OptionsController

  it "allows string keys in {domain_ctx} since it gets automatically Ctx()-wrapped" do
    controller = OptionsController.new
    controller.process(:view, params: {}).must_equal %{successObject[:authenticate, :policy, :model, :validate]}
  end


# copy from {endpoint_ctx} to {domain_ctx}
  class DomainContextController < ApplicationController
    private def _endpoint(action, seq: [], &block)
      endpoint(action, seq: seq, &block)
    end

    activity = Class.new(Trailblazer::Activity::Railway) do
      step :check

      def check(ctx, current_user:, seq:, process_model:, **)
        seq << :check
        ctx[:message] = "#{current_user} / #{process_model}"
      end
    end

    endpoint "view?", domain_activity: activity


    def self.options_for_domain_ctx(ctx, seq:, controller:, **)
      {
        seq: seq,
      }
    end

    def self.options_for_endpoint(ctx, controller:, **)
      {
        current_user: "Yogi",
        process_model: Class,
        something: true,
      }
    end

    directive :options_for_domain_ctx, method(:options_for_domain_ctx)
    directive :options_for_endpoint, method(:options_for_endpoint), inherit: false

    def view
      _endpoint "view?" do |ctx, seq:, **|
        render "success" + ctx[:message].to_s + seq.inspect
      end
    end
  end # DomainContextController

  it "{:current_user} and {:process_model} are made available in {domain_ctx}" do
    controller = DomainContextController.new
    controller.process(:view, params: {}).must_equal %{successYogi / Class[:authenticate, :policy, :check]}
  end
end

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

  it "allows to get options without a bloody controller" do
    MemoController.bla(params: params)
  end
end

