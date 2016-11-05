class SongsController < ApplicationController
  require "trailblazer/endpoint"
  include Trailblazer::Endpoint::Controller

  def create
    endpoint Create, params, { "user.current" => ::Module }
  end

  def update
    endpoint Update, params
  end

  def update_with_user
    endpoint Update, params, { "user.current" => ::Module }
  end

  def show
    endpoint Show, params, { "user.current" => ::Module }
  end
end
