require "test_helper"

class MatcherTest < Minitest::Spec
  def render(text)
    @render = text
  end

  it "what" do
    matcher = {
      success:    ->(*) { raise },
      not_found:  ->(ctx, model:, **) { render "404, #{model} not found" },
      not_authorized: ->(*) { snippet },
    }

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
    assert_equal Trailblazer::Endpoint::Matcher.(:success, [ctx, **ctx], matcher: matcher, merge: dsl.to_h, exec_context: self), %(Object)
    assert_equal Trailblazer::Endpoint::Matcher.(:not_found, [ctx, **ctx], matcher: matcher, merge: dsl.to_h, exec_context: self), %(404, Object not found)

    #@ Matcher::Value.call
    value = Trailblazer::Endpoint::Matcher::Value.new(matcher, dsl, self)
    assert_equal value.(:success, [ctx, **ctx], exec_context: self), %(Object)
  end
end

