module App
  module Api
    module V1
      module Representer
        class Errors < Representable::Decorator
          include Representable::JSON

          self.representation_wrap= :errors

          property :message
        end
      end

    end
  end
end
