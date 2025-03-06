require "test_helper"

class Controller_Test < Minitest::Spec
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
    end
  end

  it "invoke can call an operation without any endpoint logic involved" do
    controller_class = Class.new(Controller) do
      # DISCUSS: you *always* have to set a canonical invoke in a Rails app.
      kernel = Class.new do
        Trailblazer::Invoke.module!(self)
      end.new

      Trailblazer::Endpoint::Controller.module!(self, canonical_invoke: kernel.method(:__)) # DISCUSS: we always call via circuit interface (for matchers) so this is fine.

      def create
        invoke Memo::Operation::Create, seq: [], **input do
          success { |ctx, model:, **| render model.inspect }
          failure { |ctx, **| render "failure" }
        end
      end
    end

    assert_runs(
      controller_class,
      :create,

      success:            {render: %(Module)},
      # not_authorized:     {render: %(not authorized: Object), policy: false},
      # not_authenticated:  {render: %(authentication failed), authenticate: false},
      failure:            {render: %(failure), validate: false}
    )
  end
end
