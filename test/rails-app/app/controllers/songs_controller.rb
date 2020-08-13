class SongsController < ApplicationController
  endpoint("Create", domain_activity: Song::Operation::Create)

  # directive :options_for_domain_ctx, ->(ctx, **) { {seq: []} }

  def create
    endpoint "Create"
  end

  def create_with_options
    endpoint "Create", process_model: "yay!"
  end

  def create_with_or
    endpoint "Create" do |ctx, model:, **|

    end.Or do |ctx, model:, **|

    end
  end
end
