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

    # include Trailblazer::Endpoint::Controller::InstanceMethods      # {#endpoint_for}
    include Trailblazer::Endpoint::Controller::InstanceMethods::DSL # {#endpoint}

    include Trailblazer::Endpoint::Controller::Rails
    include Trailblazer::Endpoint::Controller::Rails::Process

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




    Protocol = Class.new(Trailblazer::Endpoint::Protocol) do
      include T.def_steps(:authenticate, :policy)
    end

    endpoint protocol: Protocol, adapter: Trailblazer::Endpoint::Adapter::Web,
    scope_domain_ctx: true
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
    private def _endpoint(action, seq: [], **options, &block)
      endpoint(action, seq: seq, **options, &block)
    end

    Activity = Class.new(Trailblazer::Activity::Railway) do
      step :check

      def check(ctx, current_user:, seq:, process_model:, **)
        seq << :check
        ctx[:message] = "#{current_user} / #{process_model}"
      end
    end

    endpoint "view?", domain_activity: Activity
    endpoint "show?", domain_activity: Activity


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

    def show
      # override existing domain_ctx
      # make options here available in steps
      _endpoint "show?", options_for_domain_ctx: {params: {id: 1}, seq: []} do |ctx, seq:, params:, **|
        render "success" + ctx[:message].to_s + seq.inspect + params.inspect
      end
    end

    def create
      # add endpoint_options
      _endpoint "show?", policy: false do |ctx, seq:, params:, **|
        render "success" + ctx[:message].to_s + seq.inspect + params.inspect
      end
    end

    # todo: test overriding endp options
      # _endpoint "show?", params: {id: 1}, process_model: "it's me!" do |ctx, seq:, params:, process_model:, **|
  end # DomainContextController

  it "{:current_user} and {:process_model} are made available in {domain_ctx}" do
    controller = DomainContextController.new
    controller.process(:view, params: {}).must_equal %{successYogi / Class[:authenticate, :policy, :check]}
  end

  it "{:seq} is overridden, {:params} made available, in {domain_ctx}" do
    controller = DomainContextController.new
    # note that {seq} is not shared anymore
    controller.process(:show, params: {}).must_equal %{successYogi / Class[:check]{:id=>1}}
  end

  it "allows passing {endpoint_options} directly" do
    controller = DomainContextController.new
    controller.process(:create, params: {}).must_equal [:authenticate, :policy, :protocol_failure_block]
  end


# Test without DSL
  class BasicController
    extend Trailblazer::Endpoint::Controller

    directive :options_for_block_options, Trailblazer::Endpoint::Controller.method(:options_for_block_options)

    def endpoint(name, &block)
      action_options = {seq: []}

      Trailblazer::Endpoint::Controller.advance_endpoint_for_controller(endpoint: endpoint_for(name), block_options: self.class.options_for(:options_for_block_options, {controller: self}), config_source: self.class, **action_options)
    end

    def head(status)
      @status = status
    end
  end

  class RodaController < BasicController
    endpoint("show?", protocol: ApplicationController::Protocol, adapter: Trailblazer::Endpoint::Adapter::Web, domain_activity: Class.new(Trailblazer::Activity::Railway) { def save(*); true; end; step :save })

    def show
      endpoint "show?"
      @status
    end
  end

  it "what" do
    RodaController.new.show.must_equal 200
  end
end

class ControllerEndpointMethodTest < Minitest::Spec
# Test {Controller::endpoint}

  class Protocol < Trailblazer::Endpoint::Protocol
    def policy(*); true; end
    def authenticate(*); true; end
  end

  class BasicController
    include Trailblazer::Endpoint::Controller.module(api: true, application_controller: true)

    directive :options_for_block_options, Trailblazer::Endpoint::Controller.method(:options_for_block_options)

    endpoint protocol: Protocol, adapter: Trailblazer::Endpoint::Adapter::Web

    def head(status)
      @status = status
    end

    def self.options_for_block_options(ctx, controller:, **)
      {
        success_block:          ->(ctx, endpoint_ctx:, **) { controller.head("#{ctx[:op]}") },
        failure_block:          ->(ctx, status:, **) {  },
        protocol_failure_block: ->(ctx, status:, **) {  }
      }
    end

    directive :options_for_block_options, method(:options_for_block_options)
  end

  class RodaController < BasicController
    class Create < Trailblazer::Activity::Railway
      def save(ctx, **); ctx[:op] = self.class; end;
      step :save
    end
    class Update < Create
    end

  # {Controller::endpoint}: {:domain_activity} defaults to {name} when not given
    endpoint Create                           # class {name}s are ok
    endpoint :update, domain_activity: Update # symbol {name} is ok

    def show
      endpoint Create
      @status
    end

    def update
      endpoint :update
      @status
    end
  end


  it "what" do
    RodaController.new.show.must_equal %{ControllerEndpointMethodTest::RodaController::Create}
    RodaController.new.update.must_equal %{ControllerEndpointMethodTest::RodaController::Update}
  end
end

