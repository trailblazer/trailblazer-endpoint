require "test_helper"

module Trailblazer
  class Endpoint_ < Trailblazer::Activity::Railway


    class PolicyChain < Trailblazer::Activity::Railway
      step :is_root?, Output(:success) => End(:success) # bypass policy chain
      # step :a?
    end

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

# TODO: document :track_color
require "trailblazer/endpoint"
require "trailblazer/endpoint/protocol"
require "trailblazer/endpoint/adapter"

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
    include T.def_steps(:model, :validate, :save, :cc_check)

    step :model,    Output(:failure) => End(:not_found)
    step :cc_check, Output(:failure) => End(:cc_invalid)
    step :validate, Output(:failure) => End(:my_validation_error)
    step :save
  end

  default_ends = {
    "End.success" => "End.success",
    "End.failure" => "End.failure",
  }
  custom_ends = {
    "End.cc_error" => "End.failure",
    "End.my_validation_error" => "End.VAL_ERR",
  }

  pp Create.to_h[:outputs]

  # Represents a classic FastTrack OP without additional ends.
  # Implicit termini:
  #   model     => not_found
  #   cc_check  => cc_invalid
  #   validate  => invalid_data
  class LegacyCreate < Trailblazer::Activity::FastTrack
    include T.def_steps(:my_policy, :model, :validate, :save, :cc_check)

    step :my_policy
    step :model
    step :cc_check, fail_fast: true
    step :validate
    step :save
  end


# we want to define API and Protocol somewhere application-wide in an explicit file.
# the domain OP/wiring we want via the endpoint builder.

  module MyTest
    # This implements the actual authentication, policies, etc.
    class Protocol < Trailblazer::Endpoint::Protocol
      include EndpointTest::T.def_steps(:authenticate, :handle_not_authenticated, :policy, :handle_not_authorized, :handle_not_found)

  # TODO: how can we make this better overridable in the endpoint generator?
      def success?(ctx, **)
        return Trailblazer::Endpoint::Protocol::Bridge::NotFound if ctx[:model] === false
        return Trailblazer::Endpoint::Protocol::Bridge::NotAuthorized if ctx[:my_policy] === false
  # for all other cases, the return value doesn't matter in {fail}.

      end
    end
  end


  class MyApiAdapter < Trailblazer::Endpoint::Adapter::API
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

    def my_401_handler(ctx, seq:, **)
      ctx[:model] = Struct.new(:error_message).new("No token")

      seq << :my_401_handler
    end
  end # MyApiAdapter

  api_create_endpoint =
    Trailblazer::Endpoint.build(
      adapter:          MyApiAdapter,
      protocol:         MyTest::Protocol,
      domain_activity:  Create,
    ) do
      ### PROTOCOL ###
      # these are arguments for the Protocol.domain_activity
      {
        # wire a non-standardized application error to its semantical pendant.
        Output(:my_validation_error) => Track(:invalid_data), # non-protocol, "application" output
        # Output(:not_found) => Track(:not_found),

        # wire an unknown end to failure.
        Output(:cc_invalid) => Track(:failure), # application error.

        Output(:not_found)        => _Path(semantic: :not_found) do # _Path will use {End(:not_found)} and thus reuse the terminus already created in Protocol.
          step :handle_not_found # FIXME: don't require steps in path!
        end
        }
    end

  api_legacy_create_endpoint =
  Trailblazer::Endpoint.build(
    # DISCUSS: how do we implement a 201 route?
    adapter:          Class.new(MyApiAdapter) { def success_render_status(ctx, **)
      ctx[:status] = 201
    end },
    protocol:         myp = Trailblazer::Endpoint::Protocol::Bridge.insert(MyTest::Protocol),
    domain_activity:  LegacyCreate,
  ) do


    # Implicit termini:
    #   model     => not_found
    #   cc_check  => cc_invalid
    #   validate  => invalid_data

    ### PROTOCOL ###
    # these are arguments for the Protocol.domain_activity
    {
      Output(:fail_fast) => Track(:failure),
        # TODO: pass_fast test
        # TODO: do we want to wire those ends to an ongoing "binary" protocol?

      # wire a non-standardized application error to its semantical pendant.
      # Output(:my_validation_error) => Track(:invalid_data), # non-protocol, "application" output
      # Output(:not_found) => Track(:not_found),

      # wire an unknown end to failure.
      # Output(:cc_invalid) => Track(:failure), # application error.

      # Output(:not_found)        => _Path(semantic: :not_found) do # _Path will use {End(:not_found)} and thus reuse the terminus already created in Protocol.
      #   step :handle_not_found # FIXME: don't require steps in path!
      # end
    }
  end

###############3 TODO #######################
  # test to wire 411 to another track (existing, known, automatically wired)
  # test wiring an unknown terminus like "cc_not_accepted" to "failure"


# TODO: should we also add a 411 route per default?
  # how do implement #success? ? in Protocol for sure


  # Here we test overriding an entire "endpoint", we want to replace {authenticate} and remove {policy} and the actual {activity}.
  class Gemauth < api_create_endpoint
    step Subprocess(
      MyTest::Protocol,
      patch: {[] => ->(*) {
        step nil, delete: :policy
        step nil, delete: :domain_activity
        step :gemserver_authenticate, replace: :authenticate, id: :authenticate, inherit: true

        # def gemserver_authenticate(ctx, gemserver_authenticate:true, **)
        #   ctx[:]
        # end
        include T.def_steps(:gemserver_authenticate)
        }
      }), replace: :protocol, inherit: true, id: :protocol
  end


  # step Invoke(), Output(:failure) => Track(:render_fail), Output(:my_validation_error) => ...

  # Invoke(Create, )


      # for login form, etc
     # endpoint, skip: [:authenticate]

# workflow always terminates on wait events/termini => somewhere, we need to interpret that
# OP ends on terminus

  let(:app_options) do
    app_options = {
      error_representer: "ErrorRepresenter",
      representer: "DiagramRepresenter",
    }
  end

  # The idea here is to bridge a FastTrack op (without standardized ends) to the Protocol termini
  it "LegacyCreate" do
  # cc_check ==> FailFast
    ctx = {seq: [], cc_check: false, **app_options}
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(api_legacy_create_endpoint, [ctx, {}], failure_block: _rails_failure_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}        # we rewire {domain.fail_fast} to {protocol.failure}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :my_policy, :model, :cc_check]}



  # 1.c **404** (NO RENDERING OF BODY!!!)
    ctx = {seq: [], model: false, **app_options}
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(api_legacy_create_endpoint, [ctx, {}], failure_block: _rails_failure_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:fail_fast>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :my_policy, :model]}
    to_h.inspect.must_equal %{{:head=>404, :render_options=>{:json=>nil}, :bla=>true}}

  # 2. **201** because the model is new.
    ctx = {seq: [], **app_options}
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(api_legacy_create_endpoint, [ctx, {}], success_block: _rails_success_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :my_policy, :model, :cc_check, :validate, :save]}
    to_h.inspect.must_equal %{{:head=>201, :render_options=>{:json=>\"DiagramRepresenter.new()\"}, :bla=>nil}}

  # **403** because my_policy fails.
    ctx = {seq: [], my_policy: false, **app_options}
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(api_legacy_create_endpoint, [ctx, {}], failure_block: _rails_failure_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:fail_fast>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :my_policy]}
  # this calls Rails default failure block
    to_h.inspect.must_equal %{{:head=>403, :render_options=>{:json=>\"ErrorRepresenter.new()\"}, :bla=>true}}
  end

  ######### API #########
  # FIXME: fake the controller
  let(:_rails_success_block) do ->(ctx, json:, status:, **) { head(status); render json: json; @bla = nil } end
  let(:_rails_failure_block) do ->(ctx, json:nil, status:, **) { head(status); render json: json; @bla = true } end # nil-JSON with 404,

  def head(code)
    @head = code
  end
  def render(options)
    @render_options = options
  end
  def to_h
    {head: @head, render_options: @render_options, bla: @bla}
  end

  it do
    puts "API"
    puts Trailblazer::Developer.render(MyApiAdapter)
    # puts
    # puts Trailblazer::Developer.render(Adapter::API::Gemauth)
    # exit


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


  # api_create_endpoint.instance_exec do

  #   step(Subprocess(MyTest::Protocol), patch: {[:protocol] => ->(*) { step :success?, delete: :success? }}, replace: :protocol, inherit: true, id: :protocol) end

# 1. 401 authenticate err
  # RENDER an error document
    ctx = {seq: [], authenticate: false, **app_options}
    # signal, (ctx, _ ) = Trailblazer::Developer.wtf?(Adapter::API, [ctx, {}])
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(api_create_endpoint, [ctx, {}], failure_block: _rails_failure_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:fail_fast>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :handle_not_authenticated, :my_401_handler]}
    # DISCUSS: where to add things like headers?
  # this calls Rails default failure block
    to_h.inspect.must_equal %{{:head=>401, :render_options=>{:json=>\"ErrorRepresenter.new(#<struct error_message=\\\"No token\\\">)\"}, :bla=>true}}
   # raise ctx.inspect

  # 1.c 404 (NO RENDERING OF BODY!!!)
    ctx = {seq: [], model: false, **app_options}
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(api_create_endpoint, [ctx, {}], failure_block: _rails_failure_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:fail_fast>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :handle_not_found]}
    to_h.inspect.must_equal %{{:head=>404, :render_options=>{:json=>nil}, :bla=>true}}

# `-- #<Class:0x0000000001ff5d88>
#     |-- Start.default
#     |-- protocol
#     |   |-- Start.default
#     |   |-- authenticate
#     |   |-- policy
#     |   |-- domain_activity
#     |   |   |-- Start.default
#     |   |   |-- model
#     |   |   `-- End.not_found
#     |   |-- handle_not_found       this is added via the block, in the PROTOCOL wiring
#     |   `-- End.not_found
#     |-- _404_status
#     |-- protocol_failure
#     `-- End.fail_fast


# 1.b 422 domain error: validation failed
  # RENDER an error document
    ctx = {seq: [], validate: false, **app_options}
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(api_create_endpoint, [ctx, {}], failure_block: _rails_failure_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :cc_check, :validate]}
  # this calls Rails default failure block
    to_h.inspect.must_equal %{{:head=>422, :render_options=>{:json=>\"ErrorRepresenter.new()\"}, :bla=>true}}
# `-- #<Class:0x0000000002e54e60>
#     |-- Start.default
#     |-- protocol
#     |   |-- Start.default
#     |   |-- authenticate
#     |   |-- policy
#     |   |-- domain_activity
#     |   |   |-- Start.default
#     |   |   |-- model
#     |   |   |-- validate
#     |   |   `-- End.my_validation_error
#     |   `-- End.invalid_data               this is wired to the {failure} track
#     |-- failure_render_config
#     |-- failure_config_status
#     |-- render_failure
#     `-- End.failure




  # 1.b2 another application error (#save), but 200 because of #failure_config_status
    ctx = {seq: [], save: false, **app_options}
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(api_create_endpoint, [ctx, {}], failure_block: _rails_failure_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :cc_check, :validate, :save]}
  # this calls Rails default failure block
              # we set status to 200 in #failure_config_status
    to_h.inspect.must_equal %{{:head=>200, :render_options=>{:json=>\"ErrorRepresenter.new()\"}, :bla=>true}}

# invalid {cc_check}=>{cc_invalid}
    ctx = {seq: [], cc_check: false, **app_options}
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(api_create_endpoint, [ctx, {}], failure_block: _rails_failure_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:failure>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :cc_check]}
  # this calls Rails default failure block
              # we set status to 200 in #failure_config_status
    to_h.inspect.must_equal %{{:head=>200, :render_options=>{:json=>\"ErrorRepresenter.new()\"}, :bla=>true}}


# 4. authorization error
    ctx = {seq: [], policy: false, **app_options}
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(api_create_endpoint, [ctx, {}], failure_block: _rails_failure_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:fail_fast>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :handle_not_authorized]}
  # this calls Rails default failure block
    to_h.inspect.must_equal %{{:head=>403, :render_options=>{:json=>\"ErrorRepresenter.new()\"}, :bla=>true}}


# 2. all OK

    ctx = {seq: [], **app_options}
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(api_create_endpoint, [ctx, {}], success_block: _rails_success_block)


    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx[:seq].inspect.must_equal %{[:authenticate, :policy, :model, :cc_check, :validate, :save]}
    ctx[:json].must_equal %{DiagramRepresenter.new()}

  # Rails default success block was called
    to_h.inspect.must_equal %{{:head=>200, :render_options=>{:json=>\"DiagramRepresenter.new()\"}, :bla=>nil}}


# 3. 401 for API::Gemauth
      # we only want to run the authenticate part!
      #
      # -- EndpointTest::Adapter::API::Gemauth
      #     |-- Start.default
      #     |-- protocol
      #     |   |-- Start.default
      #     |   |-- authenticate              <this is actually gemserver_authenticate>
      #     |   |-- handle_not_authenticated
      #     |   `-- End.not_authenticated
      #     |-- my_401_handler
      #     |-- _401_status
      #     |-- render_protocol_failure_config
      #     |-- render_protocol_failure
      #     |-- protocol_failure
      #     `-- End.fail_fast


    ctx = {seq: [], gemserver_authenticate: false, **app_options}
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(Gemauth, [ctx, {}], failure_block: _rails_failure_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:fail_fast>}
    ctx[:seq].inspect.must_equal %{[:gemserver_authenticate, :handle_not_authenticated, :my_401_handler]}
    to_h.inspect.must_equal %{{:head=>401, :render_options=>{:json=>\"ErrorRepresenter.new(#<struct error_message=\\\"No token\\\">)\"}, :bla=>true}}

  # authentication works
    # `-- EndpointTest::Adapter::API::Gemauth
    #   |-- Start.default
    #   |-- protocol
    #   |   |-- Start.default
    #   |   |-- authenticate
    #   |   `-- End.success
    #   |-- success_render_config
    #   |-- success_render_status
    #   |-- render_success
    #   `-- End.success

    ctx = {seq: [], gemserver_authenticate: true, **app_options}
    signal, (ctx, _ ) = Trailblazer::Endpoint_.with_or_etc(Gemauth, [ctx, {}], success_block: _rails_success_block)

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx[:seq].inspect.must_equal %{[:gemserver_authenticate]}
    to_h.inspect.must_equal %{{:head=>200, :render_options=>{:json=>\"DiagramRepresenter.new()\"}, :bla=>nil}}


######### Controller #########

# 1. do everything automatically
# 2. override success
# 2. override failure: suppress the automatic rendering?


  #   class MyPolicyChain < Trailblazer::Endpoint::PolicyChain
  #     step :a?
  #     step :b?
  #   end

  #   Trailblazer::Endpoint(policy: MyPolicyChain)

  #   class MyEndpoint < Trailblazer::Endpoint
  #     step MyPolicies, replace: :policy # with or without root, we have a binary outcome?
  #   end

  #   MyEndpoint.() # with operation
  #   MyEndpoint.() # with workflow

  # # op with > 2 ends
  #   {our_404: :not_found} # map ends to known ends

  # # html version
  #   run(MyEndpoint, ) do |ctx|
  #     # success
  #   end

  # # api version
  #   # if 404 ...
  #   # else default behavior
  # end




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
