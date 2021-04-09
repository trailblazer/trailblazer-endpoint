module Trailblazer
  class Endpoint
    # Grape Integration
    #
    module Grape
      module Controller
        # Make endpoint's compile time methods available in `base` and
        # instance methods available in it's routes.
        def self.included(base)
          base.extend(Trailblazer::Endpoint::Controller)

          base.helpers(
            Trailblazer::Endpoint::Controller::InstanceMethods,
            Trailblazer::Endpoint::Controller::InstanceMethods::API
          )

          base.helpers do
            # Override `Controller::InstanceMethods#config_source` to return `base`
            # as the link between compile-time and run-time config.
            #
            # @api public
            define_method(:config_source, ->{ base })
          end
        end
      end
    end
  end
end
