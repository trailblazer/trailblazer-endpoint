module Song::Operation
  class Show < Trailblazer::Operation
    step :model, Output(:failure) => End(:not_found)

    def model(ctx, params:, **)
      return unless params[:id] == "1"
      ctx[:model] = Song.new(params[:id])
    end
  end
end
