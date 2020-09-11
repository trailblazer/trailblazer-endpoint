class AuthController < ApplicationController::Web
  # We could use a fully-fledged operation here, with a contract and whatnot.
  def self.authenticate(ctx, request:, params:, **)
    if params[:username] == "yogi@trb.to" && params[:password] == "secret"
      ctx[:current_user] = User.find_by(email: params[:username])

      return true
    else
      return false # let's be extra explicit!
    end
  end

  endpoint("sign_in", domain_activity: Class.new(Trailblazer::Activity::Railway)) do
    # step nil, delete: :domain_activity
    step nil, delete: :policy
    step AuthController.method(:authenticate), replace: :authenticate, inherit: true, id: :authenticate

    {}
  end

  def self.options_for_endpoint(ctx, controller:, **)
    {
      params: controller.params,
      request: controller.request,
    }
  end

  directive :options_for_endpoint, method(:options_for_endpoint)

  def sign_in
    endpoint "sign_in" do |ctx, current_user:, **|
      session[:user_id] = current_user.id # Working on {session} is HTTP-specific and done in the controller.

      redirect_to dashboard_path
    end
  end

private

  def dashboard_path
    "/"
  end
end
