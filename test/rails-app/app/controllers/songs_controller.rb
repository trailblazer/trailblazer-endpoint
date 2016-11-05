class SongsController < ApplicationController
  require "trailblazer/endpoint"
  include Trailblazer::Endpoint::Controller

  def create
    endpoint Update, params, { "user.current" => ::Module }
  end

  def update
    endpoint Update, params
  end
end
