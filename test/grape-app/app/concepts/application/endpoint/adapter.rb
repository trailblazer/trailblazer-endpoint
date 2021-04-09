module Application::Endpoint
  class Adapter < Trailblazer::Endpoint::Adapter::API
    include Errors::Handlers
    insert_error_handler_steps!(self)
  end
end
