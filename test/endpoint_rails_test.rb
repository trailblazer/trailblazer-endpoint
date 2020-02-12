require 'test_helper'

class EndpointHandlerTest < Minitest::Spec
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

  def build_controller(test_op)
    c = Class.new do
      include Trailblazer::Endpoint::Controller

      attr_accessor :http_response

      def initialize(op)
        @test_op = op
        @http_response = {}
      end

      def render(options)
        @http_response = options
      end

      def action_ending_in(state, **p)
        endpoint(@test_op, args: [tested_state: state, params: p])
      end
    end
    c.new(test_op)
  end

  let(:controller) { build_controller(TestOperation) }

  describe ':not_found' do
    it 'returns a 404 HTTP code' do
      controller.action_ending_in(:not_found)

      _(controller.http_response[:status]).must_equal(404)
    end

    it 'returns an error message' do
      controller.action_ending_in(:not_found)

      _(controller.http_response[:json]).must_equal('Resource not found.')
    end
  end

  describe ':unauthenticated' do
    it 'returns a 401 HTTP code' do
      controller.action_ending_in(:unauthenticated)

      _(controller.http_response[:status]).must_equal(401)
    end

    it 'returns an error message' do
      controller.action_ending_in(:unauthenticated)

      _(controller.http_response[:json]).must_equal('Unauthorized.')
    end
  end

  describe ':unauthorized' do
    it 'returns a 403 HTTP code' do
      controller.action_ending_in(:unauthorized)

      _(controller.http_response[:status]).must_equal(403)
    end

    it 'returns an error message' do
      controller.action_ending_in(:unauthorized)

      _(controller.http_response[:json]).must_equal('Forbidden.')
    end
  end

  describe ':invalid_params' do
    describe 'when used with Reform' do
      TestModel = Struct.new(:id, :name)

      class TestContract < Reform::Form
        feature Reform::Form::Dry
        property :name

        validation do
          required(:name).filled
        end
      end

      class TestContractOp < Trailblazer::Operation
        step Model(TestModel, :new)
        step Contract::Build(constant: TestContract)
        step Contract::Validate(), Output(:failure) => End(:invalid_params)
      end
    end

    describe 'when used in standalone' do
      it 'returns a 422 HTTP code' do
        controller.action_ending_in(:invalid_params, {})

        _(controller.http_response[:status]).must_equal(422)
      end

      it 'returns the contract errors messages' do
        controller.action_ending_in(:invalid_params)

        _(controller.http_response[:json]).must_equal('Unprocessable entity.')
      end
    end
  end

  describe 'error message overloading' do
    class TestErrorOperation < Trailblazer::Operation
      step ->(ctx, **) { ctx['trailblazer-endpoint.error'] = 'Very error'; false },
        Output(:failure) => End(:not_found)
    end

    let(:controller) { build_controller(TestErrorOperation) }

    it 'returns the value set in `ctx[\'trailblazer-endpoint.error\']`' do
      controller.action_ending_in(:not_found)

      _(controller.http_response[:json]).must_equal('Very error')
    end
  end
end
