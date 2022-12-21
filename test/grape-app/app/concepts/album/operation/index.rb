class Album::Operation::Index < Trailblazer::Operation
  step :model

  def model(ctx, **)
    ctx[:model] = 3.times.collect{ |i| Album.new(i) }
  end
end
