require "test_helper"

class ControllerInheritanceTest < ControllerTest
  it "Controller with inherited Declarative::State" do
    application_controller = controller do
      # TODO: allow {inherit: true} to override/add only particular keys.
      endpoint do
        default_matcher do
          {
            success:        ->(*) { raise },
            not_found:      ->(ctx, seq:, **) { render "404, #{seq}" },
          }
        end

        ctx do |controller:, **|
          {
            seq: [],
            **controller.input,
          }
        end
      end

      # TODO: flow_options, kws
    end

    controller_class = Class.new(application_controller) do
      def update
        invoke Memo::Operation::Update do
          # inherit {not_found}.
          success         { |ctx, seq:, **| render seq.inspect }
          failure         { |ctx, seq:, **| render "failure #{seq}" }
        end
      end
    end

    empty_sub_controller_class = Class.new(controller_class)

    overriding_ctx_sub_controller_class = Class.new(controller_class) do
      endpoint do
        # We override the entire {ctx} which will always lead to the same outcome.
        ctx do
          {
            seq: [1, 2, 3],
          }
        end
      end

      def create
        invoke Memo::Operation::Create do
          success         { |ctx, seq:, **| render "#{seq.inspect} #{ctx.keys}" }
        end
      end
    end

    overriding_matcher_sub_controller_class = Class.new(controller_class) do
      endpoint do

        default_matcher do
          {
            not_found: ->(*) { render "absolutely no way, 404" },
          }
        end
      end

      def create
        invoke Memo::Operation::Create, protocol: true do
          success         { |ctx, seq:, **| render seq.inspect }
          failure         { |*| render "failure" }
        end
      end
    end

    assert_runs(
      controller_class,
      :update,

      success:       {render: %([:model, :save])},
      not_found:     {render: %(404, [:model]), model: false},
      failure:       {render: %(failure [:model, :save]), save: false}
    )

  # Simply inherit the behavior
    assert_runs(
      empty_sub_controller_class,
      :update,

      success:       {render: %([:model, :save])},
      not_found:     {render: %(404, [:model]), model: false},
      failure:       {render: %(failure [:model, :save]), save: false}
    )

  # Override ctx
    assert_runs(
      overriding_ctx_sub_controller_class,
      :update,

      success:       {render: %([1, 2, 3, :model, :save])},
      not_found:     {render: %([1, 2, 3, :model, :save]), model: false},
      failure:       {render: %([1, 2, 3, :model, :save]), save: false}
    )

  # Override default_matcher
    assert_runs(
      overriding_matcher_sub_controller_class,
      :update,

      success:       {render: %([:model, :save])},
      not_found:     {render: %(absolutely no way, 404), model: false},
      failure:       {render: %(failure [:model, :save]), save: false}
    )
  end
end
