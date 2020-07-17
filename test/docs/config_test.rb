require "test_helper"

# TODO
# extend empty conf methods instead of {respond_to?}
module Trailblazer
  class Endpoint
    def self.Normalizer(target:, methods:)
      normalizer = Class.new(Trailblazer::Activity::Railway) do
        # inject an empty {} for all options.
        methods.collect do |config_name|
          step Normalizer.DefaultToEmptyHash(config_name), id: :"default_#{config_name}"
        end
      end

      Normalizer::State.new(normalizer, methods)
    end

    module Normalizer
      def self.DefaultToEmptyHash(config_name)
        -> (ctx, **) { ctx[config_name] ||= {} }
      end

      def self.add_normalizer!(target, normalizer, config)
        normalizer = Normalizer.add(normalizer, target, config) # add configure steps for {subclass} to the _new_ normalizer.
        target.instance_variable_set(:@normalizer, normalizer)
        target.instance_variable_set(:@config, config)
      end

      class State < Module
        def initialize(normalizer, config)
          @normalizer = normalizer
          @config = config
        end

        # called once when extended in {ApplicationController}.
        def extended(extended)
          super

          extended.extend(Accessor)
          Normalizer.add_normalizer!(extended, @normalizer, @config)
        end

      end
      module Accessor
        def inherited(subclass)
          super

          Normalizer.add_normalizer!(subclass, @normalizer, @config)
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
            config = target.send(config_name, ctx, **ctx)
            ctx[config_name] = ctx[config_name].merge(config)
          end

          return Trailblazer::Activity::Right, [ctx, flow_options]
        }
      end
    end # Normalizer
  end
end

class ConfigTest < Minitest::Spec
  Controller = Struct.new(:params)

  class ApplicationController
    # extend Trailblazer::Endpoint.Normalizer(methods: [:options_for_endpoint, :options_for_domain_ctx])
    # extend Trailblazer::Endpoint::Normalizer::Bla
    extend Trailblazer::Endpoint.Normalizer(target: self, methods: [:options_for_endpoint, :options_for_domain_ctx])

    def self.options_for_endpoint(ctx, **)
      {
        find_process_model: true,
      }
    end
  end

  it "what" do
    puts Trailblazer::Developer.render(ApplicationController.instance_variable_get(:@normalizer))
    signal, (ctx, ) = Trailblazer::Developer.wtf?( ApplicationController.instance_variable_get(:@normalizer), [{}])
    pp ctx

    ctx.inspect.must_equal %{{:options_for_endpoint=>{:find_process_model=>true}, :options_for_domain_ctx=>{}}}

    puts Trailblazer::Developer.render(MemoController.instance_variable_get(:@normalizer))
    signal, (ctx, ) = Trailblazer::Developer.wtf?( MemoController.instance_variable_get(:@normalizer), [{controller: Controller.new("bla")}])

    ctx.inspect.must_equal %{{:controller=>#<struct ConfigTest::Controller params=\"bla\">, :options_for_endpoint=>{:find_process_model=>true, :params=>\"bla\"}, :options_for_domain_ctx=>{}}}
  end

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

  # it do
  #   MemoController.normalize_for(controller: "Controller")
  # end
end
