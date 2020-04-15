require "test_helper"

module Trailblazer
  def self.Endpoint(policy:, **)

  end

  class Endpoint_ < Trailblazer::Activity::Railway

    class PolicyChain < Trailblazer::Activity::Railway
      step :is_root?, Output(:success) => End(:success) # bypass policy chain
      # step :a?
    end

    class Invoke
      def self.call(ctx, **)

      end
    end

    step :authenticate,     id: :authenticate,  Output(:failure) => Track(:not_authenticated) # user from cookie, etc
    step PolicyChain,       id: :policy,        Output(:failure) => Track(:not_authorized) # missing credentials vs. no authorization
    # step Workflow::Advance::Controller (decrypt, thaw, invoke, ...)
    step Invoke, id: :invoke # per default: normal OP
    step :success? # "map" the OPs terminus to to a terminus here (404, etc) and allow to rewire
      # Output(404) => ...Track(404)
      # Output(401) => ...Track(401)




    def self.with_or_etc(activity, args, failure_block: nil, success_block: nil) # FIXME: blocks required?
      signal, (ctx, _ ) = Trailblazer::Developer.wtf?(activity, args)

      # if signal < Trailblazer::Activity::End::Success
        puts "@@@@@ #{signal.inspect}"
      if [:failure, :fail_fast].include?(signal.to_h[:semantic])
        failure_block.(ctx, **ctx)
      else
        success_block.(ctx, **ctx)
      end

      return signal, [ctx]
    end
  end
  # DISCUSS: should this also be part of an endpoint-lib activity?
end

class EndpointTest < Minitest::Spec
  T = Trailblazer::Activity::Testing
  #   policies
  #    policy.success?
  # invoke
  #   Workflow::Advance [or simple OP]
  # success? [standardized "result" object that holds end signal and ctx]

# controller [this code must be executed in the controller instance, but should be "Rails independent"]
#  "injectable" policy (maybe also on controller level, configurable)

#   if success yield
#   Or.()


  # test with authenticated user
  #      without user but for a "free" action


  # Example OP with three termini
  class Create < Trailblazer::Activity::Railway
    include T.def_steps(:model, :validate, :save)

    step :model,    Output(:failure) => End(:not_found)
    step :validate, Output(:failure) => End(:validation_error)
    step :save
  end

  default_ends = {
    "End.success" => "End.success",
    "End.failure" => "End.failure",
  }
  custom_ends = {
    "End.cc_error" => "End.failure",
    "End.validation_error" => "End.VAL_ERR",
  }

pp Create.to_h[:outputs]

# TODO: document :track_color

class PrototypeEndpoint < Trailblazer::Activity::Railway
  class Failure < Trailblazer::Activity::End # DISCUSS: move to Act::Railway?
    class Authentication < Failure
    end
  end

  def self._Path(semantic:, &block)
    Path(track_color: semantic, end_id: "End.#{semantic}", end_task: Failure::Authentication.new(semantic: semantic), &block)
  end

  # step :authenticate, Output(:failure) => Path(track_color: :not_authenticated,
  #   connect_to: Id(:handle_not_authenticated)) do# user from cookie, etc

  #   step :a
  # end
  include T.def_steps(:authenticate, :handle_not_authenticated, :policy, :handle_not_authorized, :handle_not_found)

  # step :authenticate, Output(:failure) => Track(:_not_authenticated)
  step :authenticate, Output(:failure) => _Path(semantic: :not_authenticated) do
      step :handle_not_authenticated
    end

  step :policy, Output(:failure) => _Path(semantic: :not_authorized) do # user from cookie, etc
    step :handle_not_authorized
  end

  # Here, we test a domain OP with ADDITIONAL explicit ends that get wired to the Adapter (vaidation_error => failure).
  # We still need to test the other way round: wiring a "normal" failure to, say, not_found, by inspecting the ctx.
  step Subprocess(Create), # we have S/F/NF/VE outputs
    Output(:validation_error) => Track(:failure),
    Output(:not_found) => _Path(semantic: :not_found) do
      step :handle_not_found # FIXME: don't require steps in path!
    end

  # success
  # failure
  # not_authenticated
  # not_authorized
  # not_found
  # validation_error => failure
end

# The idea is to use the PrototypeEndpoint's outputs as some kind of protocol, outcomes that need special handling
# can be wired here, or merged into one (e.g. 401 and failure is failure).
# I am writing this class in the deep forests of the Algarve, hiding from the GNR.
class Adapter < Trailblazer::Activity::FastTrack # TODO: naming. it's after the "application logic", more like Controller
  def self._Path(__step)
    # Path(end_id: "End.fail_fast") do
    #   step __step
    # end

    step task: __step, magnetic_to: nil, Output(:success) => End("End.fail_fast"), Output(:failure) => End("End.fail_fast")

    Id(__step)
  end

# Currently reusing End.fail_fast as a "something went wrong, but it wasn't a real application error!"
  step Subprocess(PrototypeEndpoint),
    Output(:not_authenticated)  => _Path(:redirect_to_login),
    Output(:not_authorized)     => _Path(:render_401),
    Output(:not_found)          => _Path(:render_404)
    step :exec_success
    fail :exec_or # this would be rendering the erroring form, as an example.



    # gemserver_check:  head(200) : head(401) [skip authenticate, skip authorize]
    # diagram.create: (authenticate: head(401), JSON err message), (validation error/failure: head(422), JSON err document), (success: head(200))
    require "trailblazer/endpoint/adapter"
    # Adapter::API
    class API < Trailblazer::Endpoint::Adapter::API
      # example how to add your own step to a certain path
                        # FIXME: :after doesn't work
      step :my_401_handler, before: :_401_status, magnetic_to: :_401, Output(:success) => Track(:_401), Output(:failure) => Track(:_401)

      def render_success(ctx, **)
        ctx[:json] = %{#{ctx[:representer]}.new(#{ctx[:model]})}
      end

      def failure_config_status(ctx, **)
        # DISCUSS: this is a bit like "success?" or a matcher.
        if ctx[:validate] === false
          ctx[:status] = 422
        else
          ctx[:status] = 200 # DISCUSS: this is the usual return code for application/domain errors, I guess?
        end
      end

# how/where would we configure each endpoint? (per action)
  # class Endpoint
  #   representer ...
  #   message ...

      def _401_(ctx, **)
        ctx[:status] = 401
        # ctx[:representer] = "ErrorRepresenter" # TODO: test 4xx override their error representer!
        ctx[:model] = Struct.new(:error_message).new("No token")
      end

      include T.def_steps(:my_401_handler)


      # def exec_success(ctx, success_block:, **)
      #   success_block.call(ctx, **ctx.to_hash) # DISCUSS: use Nested(dynamic) ?
      # end
    end

end

  # step Invoke(), Output(:failure) => Track(:render_fail), Output(:validation_error) => ...

  # Invoke(Create, )


      # for login form, etc
     # endpoint, skip: [:authenticate]

# workflow always terminates on wait events/termini => somewhere, we need to interpret that
# OP ends on terminus

  it "what" do
    puts Trailblazer::Developer.render(PrototypeEndpoint)
    puts Trailblazer::Developer.render(Adapter)
    puts "API"
    puts Trailblazer::Developer.render(Adapter::API)


# 1. authenticate works
    ctx = {seq: []}
    signal, (ctx, _ ) = Trailblazer::Developer.wtf?(PrototypeEndpoint, [ctx, {}])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :validate, :save]}

# 1. authenticate err
    ctx = {seq: [], authenticate: false}
    signal, (ctx, _ ) = Trailblazer::Developer.wtf?(PrototypeEndpoint, [ctx, {}])

    signal.inspect.must_equal %{#<EndpointTest::PrototypeEndpoint::Failure::Authentication semantic=:not_authenticated>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :handle_not_authenticated]}

# 2. model err 404
    ctx = {seq: [], model: false}
    signal, (ctx, _ ) = Trailblazer::Developer.wtf?(PrototypeEndpoint, [ctx, {}])

    signal.inspect.must_equal %{#<EndpointTest::PrototypeEndpoint::Failure::Authentication semantic=:not_found>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :handle_not_found]}

# 3. validation err
    ctx = {seq: [], validate: false}
    signal, (ctx, _ ) = Trailblazer::Developer.wtf?(PrototypeEndpoint, [ctx, {}])

  # rewired to standard failure
    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :validate]}


######### API #########
    # FIXME: fake the controller
    _rails_success_block = ->(ctx, json:, status:, **) { head(status); render json: json; @bla = nil }
    _rails_failure_block = ->(ctx, json:nil, status:, **) { head(status); render json: json; @bla = true } # nil-JSON with 404,
    def head(code)
      @head = code
    end
    def render(options)
      @render_options = options
    end
    def to_h
      {head: @head, render_options: @render_options, bla: @bla}
    end

# 1. ops indicate outcome via termini
# 2. you can still "match"
# 3. layers
# DSL .Or on top
# use TRB's wiring API to extend instead of clumsy overriding/super. Example: failure-status

=begin
    success
      representer: Api::V1::Memo::Representer
      status:      200
    failure
      representer: Api::V1::Representer::Error
      status:      422
        not_found
          representer:
          status:       404

    success_representer: Api::V1::Memo::Representer,
    failure_representer: Api::V1::Representer::Error,
    policy: MyPolicy,
=end


    app_options = {
      error_representer: "ErrorRepresenter",
      representer: "DiagramRepresenter",
    }

# 1. 401 authenticate err
  # RENDER an error document
    ctx = {seq: [], authenticate: false, **app_options}
    # signal, (ctx, _ ) = Trailblazer::Developer.wtf?(Adapter::API, [ctx, {}])
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(Adapter::API, [ctx, {}], failure_block: _rails_failure_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:fail_fast>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :handle_not_authenticated, :my_401_handler]}
    # DISCUSS: where to add things like headers?
  # this calls Rails default failure block
    to_h.inspect.must_equal %{{:head=>401, :render_options=>{:json=>\"ErrorRepresenter.new(#<struct error_message=\\\"No token\\\">)\"}, :bla=>true}}
   # raise ctx.inspect

  # 1.c 404 (NO RENDERING OF BODY!!!)
    ctx = {seq: [], model: false, **app_options}
    # signal, (ctx, _ ) = Trailblazer::Developer.wtf?(Adapter::API, [ctx, {}])
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(Adapter::API, [ctx, {}], failure_block: _rails_failure_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:fail_fast>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :handle_not_found]}
    to_h.inspect.must_equal %{{:head=>404, :render_options=>{:json=>nil}, :bla=>true}}


# 1.b 422 domain error: validation failed
  # RENDER an error document
    ctx = {seq: [], validate: false, **app_options}
    # signal, (ctx, _ ) = Trailblazer::Developer.wtf?(Adapter::API, [ctx, {}])
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(Adapter::API, [ctx, {}], failure_block: _rails_failure_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :validate]}
  # this calls Rails default failure block
    to_h.inspect.must_equal %{{:head=>422, :render_options=>{:json=>\"ErrorRepresenter.new()\"}, :bla=>true}}

  # 1.b2 another application error (#save), but 200 because of #failure_config_status
    ctx = {seq: [], save: false, **app_options}
    # signal, (ctx, _ ) = Trailblazer::Developer.wtf?(Adapter::API, [ctx, {}])
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(Adapter::API, [ctx, {}], failure_block: _rails_failure_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :validate, :save]}
  # this calls Rails default failure block
              # we set status to 200 in #failure_config_status
    to_h.inspect.must_equal %{{:head=>200, :render_options=>{:json=>\"ErrorRepresenter.new()\"}, :bla=>true}}

# 2. all OK

    ctx = {seq: [], **app_options}
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(Adapter::API, [ctx, {}], success_block: _rails_success_block)


    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :validate, :save]}
    ctx[:json].must_equal %{DiagramRepresenter.new()}

  # Rails default success block was called
    to_h.inspect.must_equal %{{:head=>200, :render_options=>{:json=>\"DiagramRepresenter.new()\"}, :bla=>nil}}

######### Controller #########

# 1. do everything automatically
# 2. override success
# 2. override failure: suppress the automatic rendering?

exit

    class MyPolicyChain < Trailblazer::Endpoint::PolicyChain
      step :a?
      step :b?
    end

    Trailblazer::Endpoint(policy: MyPolicyChain)

    class MyEndpoint < Trailblazer::Endpoint
      step MyPolicies, replace: :policy # with or without root, we have a binary outcome?
    end

    MyEndpoint.() # with operation
    MyEndpoint.() # with workflow

  # op with > 2 ends
    {our_404: :not_found} # map ends to known ends

  # html version
    run(MyEndpoint, ) do |ctx|
      # success
    end

  # api version
    # if 404 ...
    # else default behavior
  end




end

# require "test_helper"

# require "reform"
# require "trailblazer"
# require "reform/form/dry"
# require "trailblazer/endpoint"
# require "trailblazer/endpoint/rails"

# class EndpointTest < Minitest::Spec
#   Song = Struct.new(:id, :title, :length) do
#     def self.find_by(id:nil); id.nil? ? nil : new(id) end
#   end

#   require "representable/json"
#   class Serializer < Representable::Decorator
#     include Representable::JSON
#     property :id
#     property :title
#     property :length

#     class Errors < Representable::Decorator
#       include Representable::JSON
#       property :messages
#     end
#   end

#   class Deserializer < Representable::Decorator
#     include Representable::JSON
#     property :title
#   end

#   let (:my_handlers) {
#     ->(m) do
#       m.present { |result| _data << result["representer.serializer.class"].new(result["model"]).to_json }
#     end
#   }

#   #---
#   # present
#   class Show < Trailblazer::Operation
#     extend Representer::DSL
#     step Model( Song, :find_by )
#     representer :serializer, Serializer
#   end

#   # if you pass in "present"=>true as a dependency, the Endpoint will understand it's a present cycle.
#   it do
#     Trailblazer::Endpoint.new.(Show.({ id: 1 }, { "present" => true }), my_handlers)
#     _data.must_equal ['{"id":1}']
#   end

#   # passing handlers directly to Endpoint#call.
#   it do
#     result = Show.({ id: 1 }, { "present" => true })
#     Trailblazer::Endpoint.new.(result) do |m|
#       m.present { |result| _data << result["representer.serializer.class"].new(result["model"]).to_json }
#     end

#     _data.must_equal ['{"id":1}']
#   end


#   class Create < Trailblazer::Operation
#     step Policy::Guard ->(options) { options["user.current"] == ::Module }

#     extend Representer::DSL
#     representer :serializer, Serializer
#     representer :deserializer, Deserializer
#     representer :errors, Serializer::Errors
#     # self["representer.serializer.class"] = Representer
#     # self["representer.deserializer.class"] = Deserializer


#     extend Contract::DSL
#     contract do
#       property :title
#       property :length

#       include Reform::Form::Dry
#       validation :default do
#         required(:title).filled
#       end
#     end

#     step Model( Song, :new )
#     step Contract::Build()
#     step Contract::Validate( representer: self["representer.deserializer.class"] )
#     step Persist( method: :sync )
#     step ->(options) { options["model"].id = 9 }
#   end

#   let (:controller) { self }
#   let (:_data) { [] }
#   def head(*args); _data << [:head, *args] end

#   let(:handlers) { Trailblazer::Endpoint::Handlers::Rails.new(self, path: "/songs").() }
#   def render(options)
#     _data << options
#   end
#   # not authenticated, 401
#   it do
#     result = Create.( { id: 1 }, "user.current" => false )
#     # puts "@@@@@ #{result.inspect}"

#     Trailblazer::Endpoint.new.(result, handlers)
#     _data.inspect.must_equal %{[[:head, 401]]}
#   end

#   # created
#   # length is ignored as it's not defined in the deserializer.
#   it do
#     result = Create.( {}, "user.current" => ::Module, "document" => '{"id": 9, "title": "Encores", "length": 999 }' )
#     # puts "@@@@@ #{result.inspect}"

#     Trailblazer::Endpoint.new.(result, handlers)
#     _data.inspect.must_equal '[[:head, 201, {:location=>"/songs/9"}]]'
#   end

#   class Update < Create
#     self.~ Model( :find_by )
#   end

#   # 404
#   it do
#     result = Update.({ id: nil }, "user.current" => ::Module, "document" => '{"id": 9, "title": "Encores", "length": 999 }' )

#     Trailblazer::Endpoint.new.(result, handlers)
#     _data.inspect.must_equal '[[:head, 404]]'
#   end

#   #---
#   # validation failure 422
#   # success
#   it do
#     result = Create.({}, "user.current" => ::Module, "document" => '{ "title": "" }')
#     Trailblazer::Endpoint.new.(result, handlers)
#     _data.inspect.must_equal '[{:json=>"{\\"messages\\":{\\"title\\":[\\"must be filled\\"]}}", :status=>422}]'
#   end


#   include Trailblazer::Endpoint::Controller
#   #---
#   # Controller#endpoint
#   # custom handler.
#   it do
#     invoked = nil

#     endpoint(Update, { id: nil }) do |res|
#       res.not_found { invoked = "my not_found!" }
#     end

#     invoked.must_equal "my not_found!"
#     _data.must_equal [] # no rails code involved.
#   end

#   # generic handler because user handler doesn't match.
#   it do
#     invoked = nil

#     endpoint( Update, { id: nil }, args: {"user.current" => ::Module} ) do |res|
#       res.invalid { invoked = "my invalid!" }
#     end

#     _data.must_equal [[:head, 404]]
#     invoked.must_equal nil
#   end

#   # only generic handler
#   it do
#     endpoint(Update, { id: nil })
#     _data.must_equal [[:head, 404]]
#   end
# end
