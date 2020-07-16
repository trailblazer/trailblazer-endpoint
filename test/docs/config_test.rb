require "test_helper"

module Trailblazer
  class Endpoint
    def self.Normalizer(target:, methods:)
      normalizer = Class.new(Trailblazer::Activity::Railway) do
        methods.collect do |config_name|
          step Normalizer::Default.new(config_name), id: :"default_#{config_name}"
        end
      end

      normalizer = Normalizer.add(normalizer, target, methods) # {target} is the "target class".
    end

    module Normalizer
      class Default
        def initialize(config_name)
          @config_name = config_name
        end

        def call(ctx, **)
          ctx[@config_name] ||= {}
        end
      end

      module Bla
        def normalizer=(v)
          @normalizer = v
        end
        def normalizer
          @normalizer
        end

      end


      def self.add(normalizer, target, methods)
        Class.new(normalizer) do
          methods.collect do |config_name|
            step task: Normalizer.CallDirectiveMethod(target, config_name), id: "#{target}##{config_name}"
          end
        end
      end

      def self.CallDirectiveMethod(target, config_name)
        ->((ctx, flow_options), *) {

          if target.respond_to?(config_name) # this is pure magic, kinda sucks, but for configuration is ok. # TODO: add flag {strict: true}.
            config = target.send(config_name, **ctx)
            ctx[config_name] = ctx[config_name].merge(config)
          end

          return Trailblazer::Activity::Right, [ctx, flow_options]
        }
      end
    end # Normalizer
  end
end

class ConfigTest < Minitest::Spec

  class ApplicationController
    # extend Trailblazer::Endpoint.Normalizer(methods: [:options_for_endpoint, :options_for_domain_ctx])
    extend Trailblazer::Endpoint::Normalizer::Bla
    self.normalizer = Trailblazer::Endpoint.Normalizer(target: self, methods: [:options_for_endpoint, :options_for_domain_ctx])

    def self.options_for_endpoint(ctx, **)
      {
        find_process_model: true,
      }
    end
  end

  pp ApplicationController.normalizer
  pp Trailblazer::Developer.wtf?( ApplicationController.normalizer, [{}])

  class EmptyController < ApplicationController
    # for whatever reason, we don't override anything here.
  end

  class MemoController < EmptyController
    def self.options_for_endpoint(ctx, **)
      {
        request: "Request"
      }
    end

    def self.options_for_endpoint(ctx, controller:, **)
      {
        params: controller.params,
      }
    end
  end

  it do
    MemoController.normalize_for(controller: "Controller")
  end
end
