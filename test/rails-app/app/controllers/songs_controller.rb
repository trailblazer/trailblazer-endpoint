class SongsController < ApplicationController::Web
  endpoint("Create", domain_activity: Song::Operation::Create) do {} end # FIXME: we still need to provide an empty hash here if we want to override the not_found behavior.

  endpoint("sign_in", domain_activity: Song::Operation::Create) do {} end # FIXME: we still need to provide an empty hash here if we want to override the not_found behavior.

  # directive :options_for_domain_ctx, ->(ctx, **) { {seq: []} }

  def create
    endpoint "Create"
  end

  def create_with_options
    endpoint "Create", process_model: "yay!" do |ctx, model:, endpoint_ctx:, **|
      render json: [model, endpoint_ctx[:process_model]]
    end
  end

  def create_with_or
    endpoint "Create" do |ctx, model:, **|
      render json: {or: model}
    end.Or do |ctx, endpoint_ctx:, **| # :failure
      render json: endpoint_ctx.keys, status: 422
    end
  end

  def create_with_protocol_failure
    endpoint "Create" do |ctx, **|
      redirect_to dashboard_path
    end.protocol_failure do |ctx, **|
      render text: "wrong login"
    end
  end
end
