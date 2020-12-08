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


  # endpoint_ctx
  #   :resume_data
  #   domain_ctx
  #     :resume_data (copy)


  # authenticate

  # deserialize ==> {resume_data: {id: 1}}
  # deserialize_process_model_id_from_resume_data

  # find_process_model
  # policy
  # domain_activity

  # serialize suspend_data and deserialize resume_data
  class SerializeController < SongsController
    endpoint Song::Operation::Create,
      protocol: ApplicationController::Web::Protocol
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
# the entire deserialize cycle is skipped since we only use {:serialize}
  class Serialize1Controller < SerializeController
    class Create < Trailblazer::Operation
      pass ->(ctx, **) { ctx[:model] = ctx.key?(:model) ? ctx[:model] : false }
    end

    endpoint "Create",
      domain_activity: Create,
      serialize: true,
      deserialize: true

    def create
      # {:model} and {:memory} are from the domain_ctx.
      # {:encrypted_suspend_data} from endpoint.
      endpoint "Create" do |ctx, model:, endpoint_ctx:, **|
        render html: "#{model.inspect}/#{ctx[:memory].inspect}/#{endpoint_ctx[:encrypted_suspend_data]}".html_safe
      end.Or do |ctx, **| # validation failure
        render html: "xxx", status: 500
      end
    end
  end

    # TODO: not really a doc test.
# ---------deserialize cycle is skipped.
# we serialize {:remember}.
  class Serialize2Controller < Serialize1Controller # "render confirm page"
    class Create < Trailblazer::Operation
      pass ->(ctx, **) { ctx[:model] = ctx.key?(:model) ? ctx[:model] : false }
      step ->(ctx, **) { ctx[:suspend_data] = {remember: OpenStruct.new(id: 1), id: 9} }   # write to domain_ctx[:suspend_data]
    end

    endpoint "Create",
      domain_activity: Create,
      serialize: true
  end

  # we can read from {:resume_data}
  class Serialize3Controller < Serialize1Controller # "process submitted confirm page"
    class Create < Trailblazer::Operation
      pass ->(ctx, **) { ctx[:model] = ctx.key?(:model) ? ctx[:model] : false }
      pass ->(ctx, **) { ctx[:memory] = ctx[:resume_data] }                           # read/process the suspended data
    end

    endpoint "Create",
      domain_activity: Create,
      deserialize: true
  end

# find process_model via id in suspend/resume data (used to be called {process_model_from_resume_data})
  class Serialize4Controller < Serialize1Controller
    class Create < Trailblazer::Operation
      pass ->(ctx, **) { ctx[:model] = ctx.key?(:model) ? ctx[:model] : false }
      pass ->(ctx, **) { ctx[:memory] = ctx[:resume_data] }                           # read/process the suspended data
    end

    endpoint "Create",
      domain_activity: Create,
      deserialize: true,
      find_process_model: true,
      deserialize_process_model_id_from_resume_data: true

    def create
      endpoint "Create", process_model_class: Song do |ctx, endpoint_ctx:, **|
        render html: "#{endpoint_ctx[:process_model_id].inspect}/#{ctx[:memory].inspect}/#{endpoint_ctx[:encrypted_suspend_data]}".html_safe
      end
    end
  end

  # find process_model from resume
  # FIXME: what is the diff to Controller4?
  class Serialize5Controller < Serialize1Controller
    endpoint "Create",
      domain_activity: Serialize4Controller::Create,
      deserialize: true,
      find_process_model: true,
      deserialize_process_model_id_from_resume_data: true

    def create
      endpoint "Create", find_process_model: true, process_model_class: Song, process_model_id: params[:id] do |ctx, model:, endpoint_ctx:, **|
        render html: "#{model.inspect}/#{ctx[:memory].inspect}/#{endpoint_ctx[:encrypted_suspend_data]}".html_safe
      end
    end
  end

  # find process_model from action_options
  class Serialize6Controller < Serialize1Controller
    endpoint "Create",
      domain_activity: Serialize4Controller::Create,
      protocol: ApplicationController::Web::Protocol,
      find_process_model: true

    def create
      endpoint "Create", find_process_model: true, process_model_class: Song, process_model_id: params[:id] do |ctx, model:, endpoint_ctx:, **|
        render html: "#{model.inspect}/#{endpoint_ctx[:process_model].inspect}/#{endpoint_ctx[:encrypted_suspend_data]}".html_safe
      end
    end
  end

# Configure only {:find_process_model} and {:protocol}.
  class Serialize7Controller < Serialize1Controller
    endpoint find_process_model: true # generic setting for all endpoints in this controller.

    endpoint "Create", # no need to specify {:find_process_model}
      domain_activity: Serialize4Controller::Create

    endpoint "New",
      find_process_model: false,
      domain_activity: Serialize4Controller::Create

    def create
      endpoint "Create", process_model_class: Song, process_model_id: params[:id] do |ctx, model:, endpoint_ctx:, **|
        render html: "#{model.inspect}/#{endpoint_ctx[:process_model].inspect}/#{endpoint_ctx[:encrypted_suspend_data]}".html_safe
      end
    end

    def new
      endpoint "New", process_model_class: Song, process_model_id: params[:id] do |ctx, model:, endpoint_ctx:, **|
        render html: "#{model.inspect}/#{endpoint_ctx[:process_model].inspect}/#{endpoint_ctx[:encrypted_suspend_data]}".html_safe
      end
    end
  end
end
