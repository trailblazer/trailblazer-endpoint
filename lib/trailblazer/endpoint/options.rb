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

    module Options
      module DSL
        def directive(directive_name, *callables, inherit: superclass)
          options = {}

          if inherit
            options[:base_class] = instance_variable_get(:@normalizers)[directive_name] || Trailblazer::Activity::Path # FIXME
          end

          @normalizers[directive_name] = Trailblazer::Endpoint::Normalizer.Options(directive_name, *callables, **options) # DISCUSS: allow multiple calls?
        end

        def self.extended(extended) # TODO: let's hope this is only called once per hierachy :)
          extended.instance_variable_set(:@normalizers, {})
        end

        module Inherit
          def inherited(subclass)
            super

            subclass.instance_variable_set(:@normalizers, @normalizers.dup)
          end
        end
      end

      def options_for(directive_name, **runtime_options)
        normalizer = @normalizers[directive_name]

        signal, (ctx, ) = Trailblazer::Developer.wtf?(normalizer, [{directive_name => {**runtime_options}}])
        ctx[directive_name]
      end
    end

    module Normalizer
      def self.Options(directive_name, *callables, base_class: Trailblazer::Activity::Path)
        normalizer = Class.new(base_class) do
        end

        Normalizer.add(normalizer, directive_name, callables)
      end

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

      def self.add(normalizer, directive_name, options)
        Class.new(normalizer) do
          options.collect do |callable|
            step task: Normalizer.CallDirective(callable, directive_name), id: "#{directive_name}=>#{callable}"
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

    module Controller
      def self.extended(extended)
        extended.extend Trailblazer::Endpoint::Options::DSL
        extended.extend Trailblazer::Endpoint::Options::DSL::Inherit
        extended.extend Trailblazer::Endpoint::Options
      end
    end # Controller

  end
end
