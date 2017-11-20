require "./test_helper"

require "reform"
require "trailblazer"
require "reform/form/dry"
require "trailblazer/endpoint"
require "trailblazer/endpoint/rails"

class EndpointTest < Minitest::Spec
  # NOTE: Consider moving all this code to a separate class as
  # it is relevant for the test but it is boilerplate for testing
  Song = Struct.new(:id, :title, :length) do
    def self.find_by(id: nil)
      id.nil? ? nil : new(id)
    end
  end

  require "representable/json"
  class Serializer < Representable::Decorator
    include Representable::JSON
    property :id
    property :title
    property :length

    class Errors < Representable::Decorator
      include Representable::JSON
      property :messages
    end
  end

  class Deserializer < Representable::Decorator
    include Representable::JSON
    property :title
  end

  class Show < Trailblazer::Operation
    extend Representer::DSL
    step Model(Song, :find_by)
    representer :serializer, Serializer
  end

  class Create < Trailblazer::Operation
    step Policy::Guard ->(options) { options["user.current"] == ::Module }

    extend Representer::DSL
    representer :serializer, Serializer
    representer :deserializer, Deserializer
    representer :errors, Serializer::Errors

    extend Contract::DSL
    contract do
      property :title
      property :length

      include Reform::Form::Dry
      validation :default do
        required(:title).filled
      end
    end

    step Model(Song, :new)
    step Contract::Build()
    step Contract::Validate(representer: self["representer.deserializer.class"])
    step ->(options) { options["model"].id = 9 }
  end

  class Update < Trailblazer::Operation
    step Model(Song, :find_by)
  end

  describe "default matchers" do
    it "handles create" do
      result = Create.(
        {},
        "user.current" => ::Module,
        "document" => '{"id": 9, "title": "Encores", "length": 999 }'
      )
      response = Trailblazer::Endpoint.(result)
      response[:data].to_json.must_equal({ id: 9 }.to_json)
      response[:status].must_equal :created
    end

    it "handles success" do
      result = Show.(id: 1)
      response = Trailblazer::Endpoint.(result)
      response[:data].to_json.must_equal({ id: 1 }.to_json)
      response[:status].must_equal :ok
    end

    it "handles unauthenticated" do
      result = Create.(
        {},
        "document" => '{"id": 9, "title": "Encores", "length": 999 }'
      )
      response = Trailblazer::Endpoint.(result)
      response[:data].to_s.must_equal({}.to_s)
      response[:status].must_equal :unauthorized
    end

    it "handles not found" do
      result = Update.(
        { id: nil },
        "user.current" => ::Module,
        "document" => '{"id": 9, "title": "Encores", "length": 999 }'
      )
      response = Trailblazer::Endpoint.(result)
      response[:data].to_json.must_equal({}.to_s)
      response[:status].must_equal :not_found
    end

    it "handles broken contracts" do
      result = Create.(
        {},
        "user.current" => ::Module,
        "document" => '{ "title": "" }'
      )
      response = Trailblazer::Endpoint.(result)
      response[:data].must_equal({ messages: { title: ["must be filled"]}})
      response[:status].must_equal :unprocessable_entity
    end
  end

  describe "overriding locally" do
    # NOTE: Added cases will be evaluated before the defaults
    # This allows creating special cases that would else be covered
    # in a generic handler
    it "allows adding new cases" do
      result = Create.(
        {},
        "user.current" => ::Module,
        "document" => '{ "title": "" }'
      )
      super_special = {
        rule: ->(result) do
          result.failure? && result["result.contract.default"]&.failure? && result["result.contract.default"]&.errors&.messages.include?(:title)
        end,
        resolve: ->(_result, _representer) do
          { "data": { messages: ["status 200, ok but!"] }, "status": :ok }
        end
      }
      response = Trailblazer::Endpoint.(result, nil, super_special: super_special)
      response[:data].must_equal(messages: ["status 200, ok but!"])
      response[:status].must_equal :ok
    end

    it "allows re-writing the rule for existing matcher" do
      result = Create.(
        {},
        "user.current" => ::Module,
        "document" => '{ "title": "" }'
      )
      not_found_rule = ->(result) do
        result.failure? && result["result.contract.default"]&.failure? && result["result.contract.default"]&.errors&.messages.include?(:title)
      end
      response = Trailblazer::Endpoint.(result, nil, not_found: { rule: not_found_rule } )
      response[:data].must_equal({})
      response[:status].must_equal :not_found
    end

    it "allows re-writing the resolve for existing matcher" do
      result = Create.(
        {},
        "user.current" => ::Module,
        "document" => '{ "title": "" }'
      )
      contract_resolve = ->(result, _representer) do
        {
          "data": { messages: result["result.contract.default"]&.errors&.messages },
          "status": :bad_request
        }
      end
      response = Trailblazer::Endpoint.(result, nil, contract_failure: { resolve: contract_resolve } )
      response[:data].must_equal({ messages: { title: ["must be filled"]}})
      response[:status].must_equal :bad_request
    end

    it "allows re-writing the whole matcher" do
      result = Create.(
        {},
        "user.current" => ::Module,
        "document" => '{ "title": "" }'
      )
      new_contract_failure = {
        rule: ->(result) do
          result.failure?
        end,
        resolve: ->(_result, _representer) do
          { "data": { messages: ["status 200, ok but!"] }, "status": :ok }
        end
      }
      response = Trailblazer::Endpoint.(result, nil, contract_failure: new_contract_failure)
      response[:data].must_equal(messages: ["status 200, ok but!"])
      response[:status].must_equal :ok
    end
  end
end
