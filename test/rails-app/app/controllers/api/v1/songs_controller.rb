module Api
  module V1
    class SongsController < ApplicationController::Api
      endpoint Song::Operation::Create.to_s, domain_activity: Song::Operation::Create

      def create
        endpoint Song::Operation::Create.to_s, representer_class: Song::Representer
      end
    end
  end
end
