module Trailblazer
  class Endpoint
    # you don't need this if you build your endpoints manually
    class Builder < Trailblazer::Activity::Railway
      # step :build_policy
      step :build_protocol_block
      step :normalize_tuple

      # def build_policy(ctx, policies:, **)
      # end

      def build_protocol_block(ctx, policy:, **)
        ctx[:protocol_block] = -> { step Subprocess(policy), id: :policy, replace: :policy, inherit: true; {} }
      end

      def normalize_tuple(ctx, protocol_block:, options_for_build: {}, **)
        ctx[:build_options] = {
          protocol_block:    protocol_block,
          options_for_build: options_for_build
        }
      end


      module DSL
        module_function
        #
        # @return endpoint_options

        def build_options_for(builder:, **options)
          signal, (ctx, _) = builder.([options])

          ctx[:build_options] # ["web:submitted?", {protocol_block: ..., options_for_build: ...}]
        end

        def endpoint_for(id:, builder:, default_options:, **config)
          options = build_options_for(builder: builder, **config)

          return id, Trailblazer::Endpoint.build(default_options.merge(options[:options_for_build]).merge(protocol_block: options[:protocol_block]))
        end

        # {dsl_options} being something like
        #
        #   "api:Start.default" => {policies: []},
        #   "api:status?"       => {policies: [:user_owns_diagram]},
        #   "api:download?"     => {policies: [:user_owns_diagram]},
        #   "api:delete?"       => {policies: [:user_owns_diagram]},
        def endpoints_for(dsl_options, **options)
          endpoints = dsl_options.collect do |id, config|
            endpoint_for(id: id, **options, **config) # config is per endpoint, options are "global"
          end.to_h
        end
      end
    end # Builder

  end
end
