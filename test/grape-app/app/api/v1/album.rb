module V1
  class Album < V1::API
    include Trailblazer::Endpoint::Grape::Controller

    def self.options_for_endpoint(ctx, controller:, **) 
      {   
        request: controller.request,
        errors: Trailblazer::Endpoint::Adapter::API::Errors.new,
      }
    end

    def self.options_for_domain_ctx(ctx, controller:, **)
      {   
        params: controller.params,
        # current_user: current_user,  # TODO: Access current_user
      }
    end 

    def self.options_for_block_options(ctx, controller:, **)
      response_block = ->(ctx, endpoint_ctx:, **) do
        controller.body json: ctx[:model]
        controller.status endpoint_ctx[:status]
      end

      failure_block = ->(ctx, endpoint_ctx:, **) do
        controller.body json: ctx[:errors].message
        controller.status endpoint_ctx[:status]
      end

      {
        success_block:          response_block,
        failure_block:          failure_block,
        protocol_failure_block: failure_block
      }
    end

    directive :options_for_endpoint,      method(:options_for_endpoint)
    directive :options_for_domain_ctx,    method(:options_for_domain_ctx)
    directive :options_for_block_options, method(:options_for_block_options)

    endpoint ::Album::Operation::Index, protocol: Application::Endpoint::Protocol, adapter: Application::Endpoint::Adapter
    desc "Get list of albums"
    get { endpoint ::Album::Operation::Index, representer_class: ::Album::Representer }

    endpoint ::Song::Operation::Index, protocol: Application::Endpoint::Protocol, adapter: Application::Endpoint::Adapter
    endpoint ::Song::Operation::Create, protocol: Application::Endpoint::Protocol, adapter: Application::Endpoint::Adapter

    # FIXME: Use inheritance same as Rails's ApplicationController for maintaining global config
    # Grape has anonymous class scope within resource block which doesn't copy inheritance settings
    # mount ::V1::Song => ':album_id/songs'

    resource ':album_id/songs' do
      desc "Get list of songs"
      get { endpoint ::Song::Operation::Index, representer_class: ::Song::Representer }

      desc "Create a song"
      post do
        on_create = ->(ctx, model:, endpoint_ctx:, **) do
          status 201
          body json: endpoint_ctx[:representer_class].new(model).to_json
        end

        endpoint ::Song::Operation::Create, success_block: on_create, representer_class: ::Song::Representer
      end
    end
  end
end
