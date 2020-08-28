#:controller
module Api
  module V1
    class SongsController < ApplicationController::Api
      endpoint Song::Operation::Create.to_s, domain_activity: Song::Operation::Create
      endpoint Song::Operation::Show.to_s, domain_activity: Song::Operation::Show do {Output(:not_found) => Track(:not_found)} end

      def create
        endpoint Song::Operation::Create.to_s, representer_class: Song::Representer
      end

      def show
        endpoint Song::Operation::Show.to_s, representer_class: Song::Representer
      end
    end
  end
end
#:controller end
