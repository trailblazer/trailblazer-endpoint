module Trailblazer
  class EndpointActivity < Trailblazer::Activity::Path
    step :created, Output(Activity::Right, :success) => Id(:render), Output(Activity::Left, :failure) => Track(:success)
    step :deleted, Output(Activity::Right, :success) => Id(:render), Output(Activity::Left, :failure) => Track(:success)
    step :found, Output(Activity::Right, :success) => Id(:render), Output(Activity::Left, :failure) => Track(:success)
    step :success, Output(Activity::Right, :success) => Id(:render), Output(Activity::Left, :failure) => Track(:success)
    step :unauthenticated, Output(Activity::Right, :success) => Id(:render), Output(Activity::Left, :failure) => Track(:success)
    step :not_found, Output(Activity::Right, :success) => Id(:render), Output(Activity::Left, :failure) => Track(:success)
    step :invalid, Output(Activity::Right, :success) => Id(:render), Output(Activity::Left, :failure) => Track(:success)
    step :fallback, Output(Activity::Left, :failure) => Track(:success)
    step :render

    private

    def created(options, result:, **)
      return false unless result.success? && result["model.action"] == :new

      options[:result] = { "data": representer.new(result[:model]), "status": :created }
    end

    def deleted(options, result:, **)
    end

    def found(options, result:, **)
    end

    def success(options, result:, **)
    end

    def unauthenticated(options, result:, **)
    end

    def not_found(options, result:, **)
    end

    def invalid(options, result:, **)
    end

    def fallback(options, result:, **)
    end

    def render(options, **)
    end
  end
end
