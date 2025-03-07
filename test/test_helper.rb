require "minitest/autorun"
require "trailblazer/activity/dsl/linear"
require "trailblazer/activity/testing"
require "trailblazer/developer"

require "trailblazer/endpoint"

Minitest::Spec.class_eval do
  T = Trailblazer::Activity::Testing

  def assert_equal(expected, asserted, *args)
    super(asserted, expected, *args)
  end

  require "trailblazer/core"
  CU = Trailblazer::Core::Utils

  def assert_route(endpoint, ctx_additions, *route, **ctx_assumptions)
    seq = route[0..-2]
    terminus = route[-1]

    signal, (ctx, ) = Trailblazer::Developer.wtf?(endpoint, [{seq: [], domain_ctx: {}}.merge(ctx_additions)])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=#{terminus.inspect}>}
    ctx[:seq].must_equal seq

    ctx.to_h.slice(*ctx_assumptions.keys).must_equal ctx_assumptions
  end

  def activity
    activity = Class.new(Trailblazer::Activity::Railway) do
      step :model, Output(:failure) => End(:not_found)
      step :validate

      include T.def_steps(:validate, :model)
    end
  end

  class ControllerTest < Minitest::Spec
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
          step :save

          include T.def_steps(:model, :save)
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
  end
end
