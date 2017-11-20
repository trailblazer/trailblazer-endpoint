module Trailblazer
  class Endpoint
    DEFAULT_MATCHERS = {
      created: {
        rule: ->(result) { result.success? && result["model.action"] == :new },
        resolve: ->(result, representer) do
          {
            "data": representer.new(result["model"]),
            "status": :created
          }
        end
      },
      success: {
        rule: ->(result) { result.success? },
        resolve: ->(result, representer) do
          {
            "data": representer.new(result["model"]),
            "status": :ok
          }
        end
      },
      unauthenticated: {
        rule: ->(result) { result.failure? && result["result.policy.default"]&.failure? },
        resolve: ->(_result, _representer) do
          {
            "data": {},
            "status": :unauthorized
          }
        end
      },
      not_found: {
        rule: ->(result) { result.failure? && result["result.model"]&.failure? },
        resolve: ->(_result, _representer) do
          {
            "data": {},
            "status": :not_found
          }
        end
      },
      contract_failure: {
        rule: ->(result) { result.failure? && result["result.contract.default"]&.failure? },
        resolve: ->(result, _representer) do
          {
            "data": { messages: result["result.contract.default"]&.errors&.messages },
            "status": :unprocessable_entity
          }
        end
      }
    }

    # options expects a TRB Operation result
    # it might have a representer, else will assume the default name
    def self.call(operation_result, representer_class = nil, overrides = {})
      representer = operation_result["representer.serializer.class"] || representer_class
      # TODO: What to do when nothing matches?
      endpoint_opts = { result: operation_result, representer: representer }
      new.(endpoint_opts, overrides)
    end

    def call(options, overrides)
      overrides.each do |rule_key, rule_description|
        rule = rule_description[:rule] || DEFAULT_MATCHERS[rule_key][:rule]
        resolve = rule_description[:resolve] || DEFAULT_MATCHERS[rule_key][:resolve]
        if rule.nil? || resolve.nil?
          puts "Matcher is not properly set. #{rule_key} will be ignored"
          next
        end

        return resolve.(options[:result], options[:representer]) if rule.(options[:result])
      end
      matching_rules(overrides).each do |_rule_key, rule_description|
        if rule_description[:rule].(options[:result])
          return rule_description[:resolve].(options[:result], options[:representer])
        end
      end
    end

    def matching_rules(overrides)
      DEFAULT_MATCHERS.reject { |k, _v| overrides.keys.include? k }
    end
  end
end
