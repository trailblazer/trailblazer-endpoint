require 'test_helper'

class EndpointMatcherTest < Minitest::Spec
  class TestOperation < Trailblazer::Operation
    NotFound = Class.new(Trailblazer::Activity::Signal)
    Unauthenticated = Class.new(Trailblazer::Activity::Signal)
    Unauthorized = Class.new(Trailblazer::Activity::Signal)
    InvalidParams = Class.new(Trailblazer::Activity::Signal)

    SignalMatchers = {
      not_found: NotFound,
      unauthenticated: Unauthenticated,
      unauthorized: Unauthorized,
      invalid_params: InvalidParams,
    }

    step ->(_, tested_state:, **) { SignalMatchers[tested_state] || true },
      Output(NotFound, :not_found) => End(:not_found),
      Output(Unauthenticated, :unauthenticated) => End(:unauthenticated),
      Output(Unauthorized, :unauthorized) => End(:unauthorized),
      Output(InvalidParams, :invalid_params) => End(:invalid_params)
  end

  let(:my_handlers) do
    ->(m) do
      m.not_found       { |_| @its_a_match = :not_found }
      m.unauthenticated { |_| @its_a_match = :unauthenticated }
      m.unauthorized    { |_| @its_a_match = :unauthorized }
      m.invalid_params  { |_| @its_a_match = :invalid_params }
    end
  end

  before do
    @its_a_match = :no_match
  end

  # 404 :not_found
  it 'matches the :not_found state' do
    result = TestOperation.call(tested_state: :not_found)
    Trailblazer::Endpoint.new.call(result, my_handlers)

    _(@its_a_match).must_equal(:not_found)
  end

  it 'matches the :unauthenticated state' do
    result = TestOperation.call(tested_state: :unauthenticated)
    Trailblazer::Endpoint.new.call(result, my_handlers)

    _(@its_a_match).must_equal(:unauthenticated)
  end

  it 'matches the :unauthorized state' do
    result = TestOperation.call(tested_state: :unauthorized)
    Trailblazer::Endpoint.new.call(result, my_handlers)

    _(@its_a_match).must_equal(:unauthorized)
  end

  it 'matches the :unauthorized state' do
    result = TestOperation.call(tested_state: :invalid_params)
    Trailblazer::Endpoint.new.call(result, my_handlers)

    _(@its_a_match).must_equal(:invalid_params)
  end
end
