require "test_helper"

module Reform
  Form = nil
end # FIXME


Song = Struct.new(:id, :title, :length) do
  def self.find_by(id:1); id=="0" ? nil : "bla" end
end

require "trailblazer"
require "trailblazer/operation/model"
# require "reform/form/active_model/validations"
require "trailblazer/operation/contract"
require "trailblazer/operation/representer"
require "trailblazer/operation/guard"
require "trailblazer/endpoint"


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


class Create < Trailblazer::Operation
  include Policy::Guard
  policy ->(*) { self["user.current"] == ::Module }

  extend Representer::DSL
  representer :serializer, Serializer
  representer :deserializer, Deserializer
  representer :errors, Serializer::Errors
  # self["representer.serializer.class"] = Representer
  # self["representer.deserializer.class"] = Deserializer

  include Model
  model Song, :create

  include Contract::Step
  include Representer::Deserializer::JSON
  # contract do
  #   property :title
  #   property :length

  #   include Reform::Form::ActiveModel::Validations
  #   validates :title, presence: true
  # end

  # FIXME: use trb-rails and reform
  class FakeContract
    def initialize(model,*); @model = model end
    def call(params)
      if params[:title]
        @title, @length = params[:title],params[:length]
        return Trailblazer::Operation::Result.new(true, {})
      end

      return Struct.new(:errors, :success?).new(Struct.new(:messages).new({"title": ["must be set"]}), false)
    end
    def sync; @model.title = @title; @model.length = @length; end
  end

  contract FakeContract

  def process(params)
    validate(params) do |f|
      f.sync
      self["model"].id = 9
    end
  end
end

class Update < Create
  action :find_by
end

class SongsControllerTest < ActionController::TestCase
  # 404
  test "update 404" do
    post :update, params: { id: 0 }
    assert_equal 404, response.status
  end

  # 401
  test "update 401" do
    post :update, params: { id: 1 }
    assert_equal 401, response.status
  end

  # 422
  # TODO: test when no error repr set.
  test "update 422" do
    post :create, params: { id: 1 }
    assert_equal 422, response.status
    assert_equal %{{\"messages\":{\"title\":[\"must be set\"]}}}, response.body
  end
end
