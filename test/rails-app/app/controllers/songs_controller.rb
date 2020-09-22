class SongsController < ApplicationController::Web
  endpoint("Create", domain_activity: Song::Operation::Create) do {} end # FIXME: we still need to provide an empty hash here if we want to override the not_found behavior.

  # directive :options_for_domain_ctx, ->(ctx, **) { {seq: []} }

  def create_without_block
    endpoint "Create"
  end

  class CreateWithOptionsController < SongsController
    #:create-options
    def create
      endpoint "Create", session: {user_id: 2} do |ctx, current_user:, model:, **|
        render html: cell(Song::Cell::Create, model, current_user: current_user)
      end
    end
    #:create-options end
  end

  class CreateOrController < SongsController
    #:or
    def create
      endpoint "Create" do |ctx, current_user:, model:, **|
        render html: cell(Song::Cell::Create, model, current_user: current_user)
      end.Or do |ctx, contract:, **| # validation failure
        render json: contract.errors, status: 422
      end
    end
    #:or end
  end

  class CreateEndpointCtxController < SongsController
    #:endpoint_ctx
    def create
      endpoint "Create" do |ctx, endpoint_ctx:, **|
        render html: "Created", status: endpoint_ctx[:status]
      end.Or do |ctx, **| # validation failure
    #:endpoint_ctx end
      end
    end
  end

  # end.Or do |ctx, endpoint_ctx:, **| # validation failure
  #       render json: endpoint_ctx.keys, status: 422
  #     end

  #:create
  def create
    endpoint "Create" do |ctx, current_user:, model:, **|
      render html: cell(Song::Cell::Create, model, current_user: current_user)
    end.Or do |ctx, contract:, **| # validation failure
      render html: cell(Song::Cell::New, contract)
    end
  end
  #:create end

  def create_with_protocol_failure
    endpoint "Create" do |ctx, **|
      redirect_to dashboard_path
    end.protocol_failure do |ctx, **|
      render html: "wrong login, app crashed", status: 500
    end
  end
end
