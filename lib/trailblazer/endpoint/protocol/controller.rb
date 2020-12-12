module Trailblazer
  class Endpoint::Protocol
    # Deserialize incoming state.
    # Serialize outgoing state.
    # What else?
    module Controller
      module_function

      def decrypt?(ctx, encrypted_resume_data:, **)
        encrypted_resume_data
      end

      def deserialize_resume_data(ctx, decrypted_value:, **)
        ctx[:resume_data] = JSON.parse(decrypted_value)
      end

      def deserialize_process_model?(ctx, process_model_from_resume_data:, **)
        process_model_from_resume_data
      end

      def deserialize_process_model_id(ctx, resume_data:, **)
        ctx[:process_model_id] = resume_data["id"] # DISCUSS: overriding {:process_model_id}?
      end

      def encrypt?(ctx, domain_ctx:, **)
        ctx[:suspend_data] = domain_ctx[:suspend_data]
      end

      def serialize_suspend_data(ctx, suspend_data:, **)
        ctx[:serialized_suspend_data] = JSON.dump(suspend_data)
      end

      def copy_suspend_data_to_endpoint_ctx(ctx, domain_ctx:, **)
        ctx[:suspend_data] = domain_ctx[:suspend_data]
      end

# FIXME: use Model() mechanics.
      def deserialize_process_model_id_from_resume_data(ctx, resume_data:, **)
        # DISCUSS: should we warn when overriding an existing {process_model_id}?
        ctx[:process_model_id] = resume_data["id"] # DISCUSS: overriding {:process_model_id}? # FIXME: stolen from Advance___::Controller
      end

      def insert_deserialize_steps!(activity, deserialize_before: :policy)
        activity.module_eval do
          step Controller.method(:decrypt?), id: :decrypt?, before: deserialize_before # error out if no serialized_resume_data given.
          step Controller::Cipher.method(:decrypt_value), id: :decrypt,
              input: {cipher_key: :cipher_key, encrypted_resume_data: :encrypted_value}    , before: deserialize_before,
              # Output(:failure) => Track(:success),
              Output(:success) => Path(connect_to: Track(:success), track_color: :deserialize, before: deserialize_before) do # usually, Path goes into {policy}

            step Controller.method(:deserialize_resume_data), id: :deserialize_resume_data
            # DISCUSS: unmarshall?
            # step Controller.method(:deserialize_process_model_id?), id: :deserialize_process_model_id?, activity.Output(Trailblazer::Activity::Left, :failure) => activity.Id(around_activity_id)
            # step Controller.method(:deserialize_process_model_id), id: :deserialize_process_model_id

            step ->(*) { true } # FIXME: otherwise we can't insert an element AFTER :deserialize_resume_data
          end
        end
      end

      def insert_serialize_steps!(activity, serialize_after: :domain_activity)
        activity.module_eval do
            # FIXME: reverse order for insertion
          step Controller::Cipher.method(:encrypt_value), id: :encrypt                                                , after: serialize_after,
              input: {cipher_key: :cipher_key, serialized_suspend_data: :value}, output: {encrypted_value: :encrypted_suspend_data}
          step Controller.method(:serialize_suspend_data), id: :serialize_suspend_data                                , after: serialize_after
          pass Controller.method(:copy_suspend_data_to_endpoint_ctx), id: :copy_suspend_data_to_endpoint_ctx          , after: serialize_after
        end
      end

      # Insert the "experimental" {find_process_model} steps
      def insert_find_process_model!(protocol, **options)
        protocol.module_eval do
          step Subprocess(FindProcessModel), Output(:failure) => End(:not_found),
          id: :find_process_model,
          **options
            # after: :authenticate
        end

        insert_copy_to_domain_ctx!(protocol, :process_model => :model)
      end

      def insert_copy_to_domain_ctx!(protocol, variables)
        variables.each do |original_name, domain_name|
          protocol.module_eval do
            pass ->(ctx, domain_ctx:, **) { domain_ctx[domain_name] = ctx[original_name] if ctx.key?(original_name) },
              id: :"copy_[#{original_name.inspect}]_to_domain_ctx[#{domain_name.inspect}]", before: :domain_activity
          end
        end
      end
    end
  end
end
