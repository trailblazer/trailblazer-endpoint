class Trailblazer::Endpoint::Protocol
  class FindProcessModel < Trailblazer::Activity::Railway
    step :find_process_model?, Output(:failure) => Id("End.success")
    step :find_process_model#,  Output(:failure) => End(:not_found) # DISCUSS: currently, {End.failure} implies {not_found}.

    # DISCUSS: should the implementation   remain in {Activity}?
    def find_process_model?(ctx, find_process_model:, **)
      find_process_model
    end

    def find_process_model(ctx, process_model_class:, process_model_id:, **)
      ctx[:process_model] = process_model_class.find_by(id: process_model_id)
    end
  end
end
