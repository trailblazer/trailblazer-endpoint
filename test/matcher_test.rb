require "test_helper"

class MatcherTest < Minitest::Spec
  def render(text)
    @render = text
  end

  it "what" do
    matcher = Trailblazer::Endpoint::Matcher.new(
      success:    ->(*) { raise },
      not_found:  ->(ctx, model:, **) { render "404, #{model} not found" },
      not_authorized: ->(*) { snippet },
    )

    dsl = Trailblazer::Endpoint::Matcher::DSL.new

    dsl.success do |ctx, model:, **|
      render model.inspect
    end.failure do |*|
      render "failure"
    end.not_authorized do |ctx, model:, **|
      render "not authorized: #{model}"
    end

    ctx = {model: Object}

    #@ Matcher.call
    assert_equal matcher.(:success, [ctx, **ctx], merge: dsl.to_h, exec_context: self), %(Object)
    assert_equal matcher.(:not_found, [ctx, **ctx], merge: dsl.to_h, exec_context: self), %(404, Object not found)

    #@ Matcher::Value.call
    value = Trailblazer::Endpoint::Matcher::Value.new(matcher, dsl, self)
    assert_equal value.(:success, [ctx, **ctx], exec_context: self), %(Object)
  end
end

