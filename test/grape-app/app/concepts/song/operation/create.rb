class Song::Operation::Create < Trailblazer::Operation
  step :model

  def model(ctx, params:, **)
    ctx[:model] = Song.new(1, params.fetch(:album_id), "current_user.username") # TODO: Access current_user
  end
end
