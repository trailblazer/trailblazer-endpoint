require "test_helper"

class ControllerWithoutProtocolTest < Minitest::Spec
  class Controller
    attr_reader :input

    def initialize(input)
      @input = input
    end

    def render(string)
      @render = string
    end

    def to_h
      {
        render: @render,
      }
    end
  end

  module Assertion
    def assert_runs(controller_class, method, **scenarios)
      scenarios.collect do |outcome, input|
        assert_render(controller_class, method, outcome: outcome, **input)
      end
    end

    def assert_render(controller_class, method, render:, outcome:, **variables)
      controller = controller_class.new(variables)
      controller.send(method)

      assert_equal controller.to_h, {render: render}, "Outcome #{outcome.inspect} isn't valid."
    end
  end

  include Assertion

  module Memo
    module Operation
      class Create < Trailblazer::Activity::Railway
        step :model
        step :validate

        include T.def_steps(:validate)

        def model(ctx, **)
          ctx[:model] = Module
        end
      end

      class Update < Trailblazer::Activity::Railway
        step :model, Output(:failure) => End(:not_found)

        include T.def_steps(:model)
      end
    end
  end

  let(:kernel) { # DISCUSS: you *always* have to set a canonical invoke in a Rails app.
    Class.new do
      Trailblazer::Invoke.module!(self)
    end.new
  }

  def controller(kernel = self.kernel, &block)
    Class.new(Controller) do
      Trailblazer::Endpoint::Controller.module!(self, canonical_invoke: kernel.method(:__)) # DISCUSS: we always call via circuit interface (for matchers) so this is fine.
      class_eval(&block)
    end
  end

  it "invoke can call an activity without any endpoint logic involved, and no directive configured" do
    controller_class = controller do
      def create
        invoke Memo::Operation::Create, seq: [], **input do
          success { |ctx, model:, **| render model.inspect }
          failure { |ctx, **| render "failure" }
        end
      end
    end

    assert_runs(controller_class, :create,

      success:            {render: %(Module)},
      failure:            {render: %(failure), validate: false}
    )
  end

  it "allows matchers for custom termini" do
    controller_class = controller do
      def update
        invoke Memo::Operation::Update, seq: [], **input do
          success { |ctx, seq:, **| render seq.inspect }
          not_found { |ctx, seq:, **| render "404 #{seq.inspect}" }
        end
      end
    end

    assert_runs(controller_class, :update,
      success:   {render: %([:model])},
      not_found: {render: %(404 [:model]), model: false}
    )
  end

  it "allows setting default {ctx} variables via {endpoint.ctx}, but allows overriding those in {#invoke}" do
    controller_class = controller do
      endpoint do
        ctx do |controller:, **|
          {seq: [], **controller.input}
        end
      end

      def create
        invoke Memo::Operation::Create do
          success { |ctx, seq:, **| render seq.inspect }
          failure { |ctx, seq:, **| render "500 #{seq.inspect}" }
        end
      end

      # Override {:seq} ctx variable via {#invoke}.
      def create_with_explicit_variables
        invoke Memo::Operation::Create, seq: [:start] do
          success { |ctx, seq:, **| render seq.inspect }
          failure { |ctx, seq:, **| render "500 #{seq.inspect}" }
        end
      end
    end

    assert_runs(controller_class, :create,
      success:   {render: %([:validate])},
      failure: {render: %(500 [:validate]), validate: false}
    )

    assert_runs(controller_class, :create_with_explicit_variables,
      success:   {render: %([:start, :validate])},
      failure: {render: %(500 [:start, :validate]), validate: false}
    )
  end

  it "allows setting a default matcher via {endpoint.default_matcher}" do
    controller_class = controller do
      endpoint do
        ctx do |controller:, **|
          {seq: [], **controller.input}
        end

        default_matcher do
          {
            success: ->(ctx, seq:, **) { render seq.inspect },
            failure: ->(ctx, seq:, **) { render "500 #{seq.inspect}" },
          }
        end
      end

      def create_without_block
        invoke Memo::Operation::Create do end # FIXME: allow no block at all.
      end

      def create_with_partly_overriding_block
        invoke Memo::Operation::Create do
          failure { |ctx, seq:, **| render "failure! #{seq.inspect}" }
        end
      end

      def update_with_additional_handler
        invoke Memo::Operation::Update do
          not_found { |ctx, seq:, **| render "404! #{seq.inspect}" }
        end
      end
    end

    assert_runs(controller_class, :create_without_block,
      success:   {render: %([:validate])},
      failure: {render: %(500 [:validate]), validate: false}
    )

    assert_runs(controller_class, :create_with_partly_overriding_block,
      success:   {render: %([:validate])},
      failure: {render: %(failure! [:validate]), validate: false}
    )

    assert_runs(controller_class, :update_with_additional_handler,
      success:   {render: %([:model])},
      not_found: {render: %(404! [:model]), model: false}
    )
  end

  it "allows defining a {flow_options} hash, but it's not used unless canonical_invoke merges it" do
    controller_class = controller do
      endpoint do
        flow_options do ||
          {
            context_options: {
              aliases: {"seq": :sequence},
              container_class: Trailblazer::Context::Container::WithAliases,
            },
          }
        end
      end

      def create
        # There's no ctx[:sequence] as the aliasing is not merged.
        invoke Memo::Operation::Create, seq: [] do
          success { |ctx, seq:, **| render "200 #{seq.inspect} #{ctx[:sequence].inspect}" }
        end
      end
    end

    assert_runs(controller_class, :create,
      success: {render: %(200 [:validate] nil)}
    )
  end

  it "allows defining a {flow_options} hash, but it's up to the canonical_invoke block to use or merge it" do
    kernel = Class.new do
      Trailblazer::Invoke.module!(self) do |controller, activity, flow_options_from_controller:, **|
        {
          flow_options: flow_options_from_controller,
        }
      end
    end.new

    controller_class = controller(kernel) do
      endpoint do
        flow_options do || # FIXME: test block arguments.
          {
            context_options: {
              aliases: {:sequence => :seq},
              container_class: Trailblazer::Context::Container::WithAliases,
            },
          }
        end
      end

      def create
        invoke Memo::Operation::Create, sequence: [] do
          success { |ctx, seq:, **| render "200 #{seq.inspect} #{ctx[:sequence].inspect}" }
        end
      end
    end

    assert_runs(controller_class, :create,
      success: {render: %(200 [:validate] [:validate])}
    )
  end
end
