module Song::Operation
  class Create < Trailblazer::Operation
    step :contract
    step :model
    # step :validate
    # step :save

    def model(ctx, params:, **)
      return unless params[:id]
      ctx[:model] = Song.new(params[:id])
    end

    def contract(ctx, **)
      ctx[:contract] = Struct.new(:errors).new()
    end
  end
end
