class SongsController < ApplicationController
  require "trailblazer/endpoint/rails"
  include Trailblazer::Endpoint::Controller

  def create
    endpoint Create, path: songs_path, args: [ params, { "user.current" => ::Module } ]
  end

  def update
    endpoint Update, path: songs_path, args: [params]
  end

  def update_with_user
    endpoint Update, path: songs_path, args: [ params, { "user.current" => ::Module } ]
  end

  def show
    endpoint Show, path: songs_path, args: [ params, { "user.current" => ::Module } ]
  end

  def create_with_custom_handlers
    endpoint Create, path: songs_path, args: [ params, { "user.current" => ::Module } ] do |m|
      m.created { |result| render json: result["representer.serializer.class"].new(result["model"]), status: 999 }
    end
  end
end
