module Trailblazer
  class Endpoint
    DEFAULT_MATCHERS = {
      created: {
        rule: ->(result) { result.success? && result["model.action"] == :new },
        resolve: lambda do |result, representer|
          { "data": representer.new(result[:model]), "status": :created }
        end
      },
      deleted: {
        rule: ->(result) { result.success? && result["model.action"] == :destroy },
        resolve: lambda do |result, _representer|
          { "data": { id: result[:model].id }, "status": :ok }
        end
      },
      found: {
        rule: ->(result) { result.success? && result["model.action"] == :find_by },
        resolve: lambda do |result, representer|
          { "data": representer.new(result[:model]), "status": :ok }
        end
      },
      success: {
        rule: ->(result) { result.success? },
        resolve: lambda do |result, representer|
          data = if representer
                   representer.new(result[:results])
                 else
                   result[:results]
                 end
          { "data": data, "status": :ok }
        end
      },
      unauthenticated: {
        rule: ->(result) { result.policy_error? },
        resolve: ->(_result, _representer) { { "data": {}, "status": :unauthorized } }
      },
      not_found: {
        rule: ->(result) { result.failure? && result["result.model"]&.failure? },
        resolve: lambda do |result, _representer|
          {
            "data": { errors: result["result.model.errors"] },
            "status": :unprocessable_entity
          }
        end
      },
      invalid: {
        rule: ->(result) { result.failure? },
        resolve: lambda do |result, _representer|
          {
            "data": { errors: result.errors || result[:errors] },
            "status": :unprocessable_entity
          }
        end
      },
      fallback: {
        rule: ->(_result) { true },
        resolve: lambda do |_result, _representer|
          { "data": { errors: "Can't process the result" },
            "status": :unprocessable_entity }
        end
      }
    }.freeze

    # NOTE: options expects a TRB Operation result
    # it might have a representer, else will assume the default name
    def self.call(operation_result, representer_class = nil, overrides = {})
      endpoint_opts = { result: operation_result, representer: representer_class }
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
      DEFAULT_MATCHERS.except(*overrides.keys)
    end
  end
end
