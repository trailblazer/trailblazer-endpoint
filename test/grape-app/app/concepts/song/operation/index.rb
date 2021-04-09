class Song::Operation::Index < Trailblazer::Operation
  step :model

  def model(ctx, **)
    ctx[:model] = 3.times.collect{ |i| Song.new(i) }
  end
end
