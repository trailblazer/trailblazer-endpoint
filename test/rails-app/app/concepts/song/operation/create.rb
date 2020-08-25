module Song::Operation
  class Create < Trailblazer::Operation
    # include Trailblazer::Activity::Testing.def_steps(:model, :validate, :save)
    step :model
    # step :validate
    # step :save

    def model(ctx, params:, **)
      return unless params[:id]
      ctx[:model] = Song.new(params[:id])
    end
  end
end
