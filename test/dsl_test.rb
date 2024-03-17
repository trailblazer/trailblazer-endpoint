require "test_helper"

class DSLMatcherTest < Minitest::Spec
  it "what" do
    matcher = Trailblazer::Endpoint::DSL::Matcher.new({})

    matcher.success do |ctx, model:, **|
      render model.inspect
    end.failure do |*|
      render "failure"
    end.not_authorized do |ctx, model:, **|
      render "not authorized: #{model}"
    end

    default_blocks = {
      not_found: ->(*) { raise },
      not_authorized: ->(*) { snippet },
    }

    options, matchers = matcher.to_h(default_blocks)
    matchers = matchers.collect { |k, v| [k, v.inspect.split(".rb").last] }

    assert_equal options.inspect, %(nil)
    assert_equal matchers.to_h.inspect, %({:not_found=>":16 (lambda)>", :not_authorized=>":11>", :success=>":7>", :failure=>":9>"})
  end
end
