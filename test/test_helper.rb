require "minitest/autorun"
require "trailblazer/activity/dsl/linear"
require "trailblazer/activity/testing"
require "trailblazer/developer"

require "trailblazer/endpoint"
require "trailblazer/endpoint/protocol"
require "trailblazer/endpoint/adapter"

require "test_helper"

Minitest::Spec.class_eval do
  T = Trailblazer::Activity::Testing

  def assert_route(endpoint, ctx_additions, *route, **ctx_assumptions)
    seq = route[0..-2]
    terminus = route[-1]

    signal, (ctx, ) = Trailblazer::Developer.wtf?(endpoint, [{seq: [], domain_ctx: {}}.merge(ctx_additions)])
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=#{terminus.inspect}>}
    ctx[:seq].must_equal seq

    ctx.to_h.slice(*ctx_assumptions.keys).must_equal ctx_assumptions
  end
end
