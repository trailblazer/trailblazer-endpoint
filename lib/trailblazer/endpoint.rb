require "dry/matcher"

module Trailblazer
  class Endpoint
    Matcher = Dry::Matcher.new(
      not_found: Dry::Matcher::Case.new { |result| result_error_matching?(result, :not_found) ? result : Dry::Matcher::Undefined },
      unauthenticated: Dry::Matcher::Case.new { |result| result_error_matching?(result, :unauthenticated) ? result : Dry::Matcher::Undefined },
      unauthorized: Dry::Matcher::Case.new { |result| result_error_matching?(result, :unauthorized) ? result : Dry::Matcher::Undefined },
      invalid_params: Dry::Matcher::Case.new { |result| result_error_matching?(result, :invalid_params) ? result : Dry::Matcher::Undefined },
    )

    class << self
      # `call`s the operation.
      def call(operation_class, handlers, *args, &block)
        result = operation_class.(*args)
        new.(result, handlers, &block)
      end

      private

      def result_error_matching?(result, state)
        end_state = result.event.to_h[:semantic]
        result.failure? && end_state == state
      end
    end

    def call(result, handlers=nil, &block)
      matcher.(result, &block) and return if block_given? # evaluate user blocks first.
      matcher.(result, &handlers)     # then, generic Rails handlers in controller context.
    end

    def matcher
      Matcher
    end

    module Controller
      # endpoint(Create) do |m|
      #   m.not_found { |result| .. }
      # end
      def endpoint(operation_class, options={}, &block)
        handlers = Handlers::Rails.new(self, options).()
        Endpoint.(operation_class, handlers, *options[:args], &block)
      end
    end
  end
end
