#:endpoint
#:or
#:create
class SongsController < ApplicationController::Web
  endpoint Song::Operation::Create

#:endpoint end
  def create
    endpoint Song::Operation::Create do |ctx, current_user:, model:, **|
      render html: cell(Song::Cell::Create, model, current_user: current_user)
    end.Or do |ctx, contract:, **| # validation failure
      render html: cell(Song::Cell::New, contract)
    end
  end
#:create end

#~oskip
  class CreateOrController < SongsController
#~oskip end
  def create
    endpoint Song::Operation::Create do |ctx, current_user:, model:, **|
      render html: cell(Song::Cell::Create, model, current_user: current_user)
    end.Or do |ctx, contract:, **| # validation failure
      render json: contract.errors, status: 422
    end
  end
end
#:or end

  def create_without_block
    endpoint Song::Operation::Create
  end

  class CreateWithOptionsController < SongsController
    #:create-options
    def create
      endpoint Song::Operation::Create, session: {user_id: 2} do |ctx, current_user:, model:, **|
        render html: cell(Song::Cell::Create, model, current_user: current_user)
      end
    end
    #:create-options end
  end


  class CreateWithOptionsForDomainCtxController < SongsController
    #:domain_ctx
    def create
      endpoint Song::Operation::Create, options_for_domain_ctx: {params: {id: 999}} do |ctx, model:, **|
        render html: cell(Song::Cell::Create, model)
      end
    end
    #:domain_ctx end
  end

  class CreateEndpointCtxController < SongsController
    #:endpoint_ctx
    def create
      endpoint Song::Operation::Create do |ctx, endpoint_ctx:, **|
        render html: "Created", status: endpoint_ctx[:status]
      end.Or do |ctx, **| # validation failure
        #~empty
        #~empty end
      end
    end
    #:endpoint_ctx end
  end

  # end.Or do |ctx, endpoint_ctx:, **| # validation failure
  #       render json: endpoint_ctx.keys, status: 422
  #     end


  class CreateWithProtocolFailureController < SongsController
  #:protocol_failure
  def create_with_protocol_failure
    endpoint Song::Operation::Create do |ctx, **|
      redirect_to dashboard_path
    end.protocol_failure do |ctx, **|
      render html: "wrong login, app crashed", status: 500
    end
  end
  #:protocol_failure end
  end


  # serialize suspend_data and deserialize resume_data
  class SerializeController < SongsController
   def self.process_model_in_domain_ctx
      ->(_ctx, ((ctx, a), b)) {
        ctx[:domain_ctx][:model]  = ctx[:process_model] if ctx.key?(:process_model)
        ctx[:domain_ctx][:memory] = ctx[:resume_data] #if ctx.key?(:memory)

        [_ctx, [[ctx, a], b]]
      } # FIXME: extract to lib?
    end

    endpoint Song::Operation::Create,
      protocol: ApplicationController::Web::SerializingProtocol,
      domain_ctx_filter: process_model_in_domain_ctx
      # serialize: true

    def self.options_for_block_options(ctx, **)
      {
        invoke: Trailblazer::Developer.method(:wtf?) # FIXME
      }
    end


    def self.options_for_endpoint(ctx, controller:, **)
      {
        cipher_key: Rails.application.config.cipher_key,

        encrypted_resume_data: controller.params[:encrypted_resume_data],
      }
    end

    directive :options_for_block_options, method(:options_for_block_options)
    directive :options_for_endpoint, method(:options_for_endpoint)

    def create
      encrypted_value = Trailblazer::Workflow::Cipher.encrypt_value({}, cipher_key: cipher_key, value: JSON.dump({id: "findings received", class: Object}))

      endpoint Song::Operation::Create, encrypted_resume_data: encrypted_value, process_model_from_resume_data: false do |ctx, current_user:, endpoint_ctx:, **|
        render html: cell(Song::Cell::Create, model, current_user: current_user)
      end.Or do |ctx, contract:, **| # validation failure
        render html: cell(Song::Cell::New, contract)
      end
    end
  end

  # TODO: not really a doc test.
# When {:encrypted_resume_data} is {nil} the entire deserialize cycle is skipped.
  class Serialize1Controller < SerializeController
    class Create < Trailblazer::Operation
      pass ->(ctx, **) { ctx[:model] = ctx.key?(:model) ? ctx[:model] : false }
    end

    endpoint "Create",
      domain_activity: Create,
      protocol: ApplicationController::Web::SerializingProtocol,
      domain_ctx_filter: process_model_in_domain_ctx

    def create
      # {:model} and {:memory} are from the domain_ctx.
      # {:encrypted_suspend_data} from endpoint.
      endpoint "Create" do |ctx, model:, memory:, endpoint_ctx:, **|
        render html: "#{model.inspect}/#{memory.inspect}/#{endpoint_ctx[:encrypted_suspend_data]}".html_safe
      end.Or do |ctx, **| # validation failure
        raise
      end
    end
  end

    # TODO: not really a doc test.
# ---------deserialize cycle is skipped.
# we serialize {:remember}.
  class Serialize2Controller < Serialize1Controller # "render confirm page"
    class Create < Trailblazer::Operation
      pass ->(ctx, **) { ctx[:model] = ctx.key?(:model) ? ctx[:model] : false }
      step ->(ctx, **) { ctx[:suspend_data] = {remember: OpenStruct.new(id: 1)} }   # write to domain_ctx[:suspend_data]
    end

    endpoint "Create",
      domain_activity: Create,
      protocol: ApplicationController::Web::SerializingProtocol,
      domain_ctx_filter: process_model_in_domain_ctx
  end

  class Serialize3Controller < Serialize1Controller # "process submitted confirm page"
    class Create < Trailblazer::Operation
      pass ->(ctx, **) { ctx[:model] = ctx.key?(:model) ? ctx[:model] : false }
      # pass ->(ctx, **) { ctx[:remember] = ctx[:model] : false }
      # step ->(ctx, **) { ctx[:suspend_data] = {remember: OpenStruct.new(id: 1)} }   # write to domain_ctx[:suspend_data]
    end

    endpoint "Create",
      domain_activity: Create,
      protocol: ApplicationController::Web::SerializingProtocol,
      domain_ctx_filter: process_model_in_domain_ctx
  end

end
