module Song
  module Operation
    class Create < Trailblazer::Operation
      # include Trailblazer::Activity::Testing.def_steps(:model, :validate, :save)
      step :model
      # step :validate
      # step :save

      def model(ctx, params:, **)
        ctx[:model] = params[:id]
      end
    end
  end
end
