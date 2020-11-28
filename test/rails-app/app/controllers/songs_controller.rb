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
    endpoint Song::Operation::Create,
      protocol: ApplicationController::Web::SerializingProtocol#,
      # serialize: true

    def self.options_for_block_options(ctx, **)
      {
        invoke: Trailblazer::Developer.method(:wtf?) # FIXME
      }
    end

    directive :options_for_block_options, method(:options_for_block_options)


    def create

      cipher_key = "e1e1cc87asdfasdfasdfasfdasdfasdfasvhnfvbdb"

      encrypted_value = Trailblazer::Workflow::Cipher.encrypt_value({}, cipher_key: cipher_key, value: JSON.dump({id: "findings received", class: Object}))

      endpoint Song::Operation::Create, cipher_key: cipher_key, encrypted_resume_data: encrypted_value, process_model_from_resume_data: false do |ctx, current_user:, endpoint_ctx:, **|
        render html: cell(Song::Cell::Create, model, current_user: current_user)
      end.Or do |ctx, contract:, **| # validation failure
        render html: cell(Song::Cell::New, contract)
      end
    end
  end
end
