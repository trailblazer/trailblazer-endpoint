#:controller
module Api
  module V1
    class SongsController < ApplicationController::Api
      endpoint Song::Operation::Create
      endpoint Song::Operation::Show do
        {Output(:not_found) => Track(:not_found)}  # add additional wiring to {domain_activity}
      end

      #:create
      def create
        endpoint Song::Operation::Create, representer_class: Song::Representer
      end
      #:create end

      #~empty
      def show
        endpoint Song::Operation::Show, representer_class: Song::Representer
      end

      def show_with_options
        endpoint Song::Operation::Show, representer_class: Song::Representer, protocol_failure_block: ->(ctx, endpoint_ctx:, **) { head endpoint_ctx[:status] + 1 }
      end

      class WithOptionsController < ApplicationController::Api
        endpoint Song::Operation::Show do {Output(:not_found) => Track(:not_found)} end

        #:show-options
        def show
          endpoint Song::Operation::Show, representer_class: Song::Representer,
            protocol_failure_block: ->(ctx, endpoint_ctx:, **) { head endpoint_ctx[:status] + 1 }
        end
        #:show-options end
      end
      #~empty end
    end
  end
end
#:controller end
