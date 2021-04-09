module Application::Endpoint
  class Protocol < Trailblazer::Endpoint::Protocol
    def authenticate(ctx, controller:, **)
      username, password = Rack::Auth::Basic::Request.new(controller.env).credentials
      return false if username != password

      ctx[:current_user] = User.new(username)
    end

    def policy(ctx, current_user:, **)
      current_user.username == 'admin'
    end
  end
end
