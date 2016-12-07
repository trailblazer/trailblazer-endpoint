require "test_helper"

require "reform"
require "trailblazer"
require "reform/form/dry"
require "trailblazer/endpoint"
require "trailblazer/endpoint/rails"

class EndpointTest < Minitest::Spec
  Song = Struct.new(:id, :title, :length) do
    def self.find_by(id:nil); id.nil? ? nil : new(id) end
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

  let (:my_handlers) {
    ->(m) do
      m.present { |result| _data << result["representer.serializer.class"].new(result["model"]).to_json }
    end
  }

  #---
  # present
  class Show < Trailblazer::Operation
    extend Representer::DSL
    step Model( Song, :find_by )
    representer :serializer, Serializer
  end

  # if you pass in "present"=>true as a dependency, the Endpoint will understand it's a present cycle.
  it do
    Trailblazer::Endpoint.new.(Show.({ id: 1 }, { "present" => true }), my_handlers)
    _data.must_equal ['{"id":1}']
  end

  # passing handlers directly to Endpoint#call.
  it do
    result = Show.({ id: 1 }, { "present" => true })
    Trailblazer::Endpoint.new.(result) do |m|
      m.present { |result| _data << result["representer.serializer.class"].new(result["model"]).to_json }
    end

    _data.must_equal ['{"id":1}']
  end


  class Create < Trailblazer::Operation
    step Policy::Guard ->(options) { options["user.current"] == ::Module }

    extend Representer::DSL
    representer :serializer, Serializer
    representer :deserializer, Deserializer
    representer :errors, Serializer::Errors
    # self["representer.serializer.class"] = Representer
    # self["representer.deserializer.class"] = Deserializer


    extend Contract::DSL
    contract do
      property :title
      property :length

      include Reform::Form::Dry
      validation :default do
        required(:title).filled
      end
    end

    step Model( Song, :new )
    step Contract::Build()
    step Contract::Validate( representer: self["representer.deserializer.class"] )
    step Persist( method: :sync )
    step ->(options) { options["model"].id = 9 }
  end

  let (:controller) { self }
  let (:_data) { [] }
  def head(*args); _data << [:head, *args] end

  let(:handlers) { Trailblazer::Endpoint::Handlers::Rails.new(self, path: "/songs").() }
  def render(options)
    _data << options
  end
  # not authenticated, 401
  it do
    result = Create.( { id: 1 }, "user.current" => false )
    # puts "@@@@@ #{result.inspect}"

    Trailblazer::Endpoint.new.(result, handlers)
    _data.inspect.must_equal %{[[:head, 401]]}
  end

  # created
  # length is ignored as it's not defined in the deserializer.
  it do
    result = Create.( {}, "user.current" => ::Module, "document" => '{"id": 9, "title": "Encores", "length": 999 }' )
    # puts "@@@@@ #{result.inspect}"

    Trailblazer::Endpoint.new.(result, handlers)
    _data.inspect.must_equal '[[:head, 201, {:location=>"/songs/9"}]]'
  end

  class Update < Create
    self.~ Model( :find_by )
  end

  # 404
  it do
    result = Update.({ id: nil }, "user.current" => ::Module, "document" => '{"id": 9, "title": "Encores", "length": 999 }' )

    Trailblazer::Endpoint.new.(result, handlers)
    _data.inspect.must_equal '[[:head, 404]]'
  end

  #---
  # validation failure 422
  # success
  it do
    result = Create.({}, "user.current" => ::Module, "document" => '{ "title": "" }')
    Trailblazer::Endpoint.new.(result, handlers)
    _data.inspect.must_equal '[{:json=>"{\\"messages\\":{\\"title\\":[\\"must be filled\\"]}}", :status=>422}]'
  end


  include Trailblazer::Endpoint::Controller
  #---
  # Controller#endpoint
  # custom handler.
  it do
    invoked = nil

    endpoint(Update, { id: nil }) do |res|
      res.not_found { invoked = "my not_found!" }
    end

    invoked.must_equal "my not_found!"
    _data.must_equal [] # no rails code involved.
  end

  # generic handler because user handler doesn't match.
  it do
    invoked = nil

    endpoint( Update, { id: nil }, args: {"user.current" => ::Module} ) do |res|
      res.invalid { invoked = "my invalid!" }
    end

    _data.must_equal [[:head, 404]]
    invoked.must_equal nil
  end

  # only generic handler
  it do
    endpoint(Update, { id: nil })
    _data.must_equal [[:head, 404]]
  end
end
