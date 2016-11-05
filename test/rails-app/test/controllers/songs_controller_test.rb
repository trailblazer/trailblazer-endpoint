require "test_helper"

module Reform
  Form = nil
end # FIXME


Song = Struct.new(:id, :title, :length) do
  def self.find_by(id:1); id=="0" ? nil : new(id, "A Song") end
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
      self["contract"].sync
      self["model"].id = 9
    end
  end
end

class Update < Create
  action :find_by
end

# TODO: test present.
class Show < Trailblazer::Operation
  include Policy::Guard
  policy ->(*) { self["user.current"] == ::Module }

  extend Representer::DSL
  representer :serializer, Serializer

  include Model
  model Song, :find_by

  self.> ->(input, options) { options["present"] = true }, before: "operation.result"
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

  # 201
  test "create 201" do
    post :create, params: { id: 1, title: "AVH" }
    assert_equal 201, response.status
    assert_equal %{}, response.body
    assert_equal "/songs/9", response.header["Location"]
  end

  # 200 present
  test "show 200" do
    get :show, params: { id: 1 }
    assert_equal 200, response.status
    assert_equal %{{"id":"1","title":"A Song"}}, response.body
  end

  # 201 update
  test "update 200" do
    post :update_with_user, params: { id: 1, title: "AVH" }
    assert_equal 200, response.status
    assert_equal %{}, response.body
    assert_equal "/songs/9", response.header["Location"]
  end

  # custom 999
  test "custom 999" do
    post :create_with_custom_handlers, params: { id: 1, title: "AVH" }
    assert_equal 999, response.status
    assert_equal %{{"id":9,"title":"AVH"}}, response.body
  end
end
