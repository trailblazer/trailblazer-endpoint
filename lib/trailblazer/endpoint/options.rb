# TODO
module Trailblazer
  class Endpoint
    def self.Normalizer(target:, options:)
      normalizer = Class.new(Trailblazer::Activity::Railway) do
        # inject an empty {} for all options.
        # options.collect do |(method_name => option)|
        #   step Normalizer.DefaultToEmptyHash(config_name), id: :"default_#{config_name}"
        # end
      end

      Normalizer::State.new(normalizer, options)
    end

    def self.Normalizer___(options, base_class: Trailblazer::Activity::Path)
      normalizer = Class.new(base_class) do
        # inject an empty {} for all options.
        # options.collect do |(method_name => option)|
        #   step Normalizer.DefaultToEmptyHash(config_name), id: :"default_#{config_name}"
        # end
      end

      Normalizer.add(normalizer, nil, options)
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

          extended.extend(Inherited)
          Normalizer.add_normalizer!(extended, @normalizer, @config)
        end

      end
      module Inherited
        def inherited(subclass)
          super

          Normalizer.add_normalizer!(subclass, @normalizer, @config)
        end
      end

      def self.add(normalizer, target, options)
        Class.new(normalizer) do
          options.collect do |(callable, option_name)|
            # FIXME
            # target.define_singleton_method(config_name) { |ctx, **| {} } # Add an empty hash per class, that is then to be overridden.
            # FIXME

            step task: Normalizer.CallDirective(callable, option_name), id: "#{option_name}=>#{callable}"
          end
        end
      end

      def self.CallDirectiveMethod(target, config_name)
        ->((ctx, flow_options), *) {
          config = target.send(config_name, ctx, **ctx) # e.g. ApplicationController.options_for_endpoint

          ctx[config_name] = ctx[config_name].merge(config)

          return Trailblazer::Activity::Right, [ctx, flow_options]
        }
      end

      def self.CallDirective(callable, option_name)
        ->((ctx, flow_options), *) {
          config = callable.(ctx, **ctx) # e.g. ApplicationController.options_for_endpoint

          ctx[option_name] = ctx[option_name].merge(config)

          return Trailblazer::Activity::Right, [ctx, flow_options]
        }
      end
    end # Normalizer
  end
end
