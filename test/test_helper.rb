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
end
