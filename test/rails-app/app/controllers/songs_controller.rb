class SongsController < ApplicationController
  require "trailblazer/endpoint"
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
end
