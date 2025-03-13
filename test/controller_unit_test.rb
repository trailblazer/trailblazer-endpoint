require "test_helper"

class ControllerWithoutProtocolTest < ControllerTest
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
      success:   {render: %([:model, :save])},
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
      success:   {render: %([:model, :save])},
      not_found: {render: %(404! [:model]), model: false}
    )
  end

  it "{endpoint.ctx} receives block arguments" do
    controller_class = controller do
      endpoint do
        ctx do |controller:, activity:, invoke_options:|
          {
            options_readable_in_ctx_block: [activity, controller.class, invoke_options]
          }
        end
      end

      def create
        invoke Trailblazer::Activity::Railway do
          success { |ctx, options_readable_in_ctx_block:, **| render options_readable_in_ctx_block }
        end
      end
    end

    assert_runs(controller_class, :create,
      success: {render: [Trailblazer::Activity::Railway, controller_class, {}]}
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

  it "{endpoint.flow_options} receives block arguments" do
    kernel = Class.new do
      Trailblazer::Invoke.module!(self) do |controller, activity, flow_options_from_controller:, **|
        {
          flow_options: flow_options_from_controller,
        }
      end
    end.new

    Activity = Class.new(Trailblazer::Activity::Railway) do
      step task: ->((ctx, flow_options), **) do
        ctx[:options_readable_in_flow_options_block] = flow_options[:options_readable_in_flow_options_block]

        return Trailblazer::Activity::Right, [ctx, flow_options]
      end
    end

    controller_class = controller(kernel) do
      endpoint do
        flow_options do |activity:, controller:, invoke_options:|
          {
            options_readable_in_flow_options_block: [activity, controller.class, invoke_options]
          }
        end
      end

      def create
        invoke Activity do
          success { |ctx, options_readable_in_flow_options_block:, **| render options_readable_in_flow_options_block }
        end
      end
    end

    assert_runs(controller_class, :create,
      success: {render: [Activity, controller_class, {}]}
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

  it "you can also override controller's flow_options by overriding {#_flow_options}" do
    kernel = Class.new do
      Trailblazer::Invoke.module!(self) do |controller, activity, flow_options_from_controller:, **|
        {
          flow_options: flow_options_from_controller,
        }
      end
    end.new

    # Test overriding {Controller#_flow_options}.
    # Test that we can call {super}.
    # Test that we have access to {**options} from {#invoke}.
    controller_class = controller(kernel) do
      # @test what options we can access in {#_flow_options}
      def _flow_options(**options)
        super.merge(
          context_options: {
            aliases: {:sequence => :seq},
            container_class: Trailblazer::Context::Container::WithAliases,
          },
        )
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

  it "is possible to use #invoke and configure it using instance methods instead of the {endpoint} DSL" do
    controller_class = controller do
      def _options_for_endpoint_ctx(controller:, **)
        {seq: [], **controller.input}
      end

      def _default_matcher_for_endpoint
        {
          success: ->(ctx, seq:, **) { render seq.inspect },
          failure: ->(ctx, seq:, **) { render "500 #{seq.inspect}" },
        }
      end

      def create
        invoke Memo::Operation::Create do end # FIXME: allow no block at all.
      end
    end

    assert_runs(controller_class, :create,
      success:   {render: %([:validate])},
      failure: {render: %(500 [:validate]), validate: false}
    )
  end
end
