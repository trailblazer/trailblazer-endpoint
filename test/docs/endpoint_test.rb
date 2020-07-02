require "test_helper"

class DocsEndpointTest < Minitest::Spec

# Show how handlers can be put onto a specific path, e.g. {handle_not_authenticated}.
  module A
    module Pro
      module Endpoint
        class Protocol < Trailblazer::Endpoint::Protocol

          # put {handle_not_authorized} on the respective protocol path.

          # we currently have to squeeze those handlers using the {:before} option, otherwise the path's End is placed before the handler in the sequence. A grouping feature could help.

          step :handle_not_authenticated, magnetic_to: :not_authenticated, Output(:success) => Track(:not_authenticated), Output(:failure) => Track(:not_authenticated), before: "End.not_authenticated"
          step :handle_not_authorized, magnetic_to: :not_authorized, Output(:success) => Track(:not_authorized), Output(:failure) => Track(:not_authorized),before: "End.not_authorized"
        end
      end
    end
  end

  it "allows to insert a (handle_not_authenticated} path step" do
    Trailblazer::Developer.render(A::Pro::Endpoint::Protocol).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=authenticate>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=authenticate>
 {Trailblazer::Activity::Left} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=handle_not_authenticated>
 {Trailblazer::Activity::Right} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=policy>
#<Trailblazer::Activity::TaskBuilder::Task user_proc=policy>
 {Trailblazer::Activity::Left} => #<Trailblazer::Activity::TaskBuilder::Task user_proc=handle_not_authorized>
 {Trailblazer::Activity::Right} => Trailblazer::Endpoint::Protocol::Noop
Trailblazer::Endpoint::Protocol::Noop
 {#<Trailblazer::Activity::End semantic=:failure>} => #<End/:failure>
 {#<Trailblazer::Activity::End semantic=:success>} => #<End/:success>
#<End/:success>

#<Trailblazer::Endpoint::Protocol::Failure/:invalid_data>

#<Trailblazer::Endpoint::Protocol::Failure/:not_found>

#<Trailblazer::Activity::TaskBuilder::Task user_proc=handle_not_authorized>
 {Trailblazer::Activity::Left} => #<Trailblazer::Endpoint::Protocol::Failure/:not_authorized>
 {Trailblazer::Activity::Right} => #<Trailblazer::Endpoint::Protocol::Failure/:not_authorized>
#<Trailblazer::Endpoint::Protocol::Failure/:not_authorized>

#<Trailblazer::Activity::TaskBuilder::Task user_proc=handle_not_authenticated>
 {Trailblazer::Activity::Left} => #<Trailblazer::Endpoint::Protocol::Failure/:not_authenticated>
 {Trailblazer::Activity::Right} => #<Trailblazer::Endpoint::Protocol::Failure/:not_authenticated>
#<Trailblazer::Endpoint::Protocol::Failure/:not_authenticated>

#<End/:failure>
}
  end
end
