require "trailblazer/endpoint/controller"

class ApplicationController < ActionController::Base
  def self.current_user_in_domain_ctx
    ->(_ctx, ((ctx, a), b)) { ctx[:domain_ctx][:current_user] = ctx[:current_user]; [_ctx, [[ctx, a], b]] } # FIXME: extract to lib?
  end
end


# directive
