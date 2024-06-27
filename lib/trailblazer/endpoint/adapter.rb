module Trailblazer
  class Endpoint

    # The idea is to use the CreatePrototypeProtocol's outputs as some kind of protocol, outcomes that need special handling
    # can be wired here, or merged into one (e.g. 401 and failure is failure).
    # I am writing this class in the deep forests of the Algarve, hiding from the GNR.
    # class Adapter < Trailblazer::Activity::FastTrack # TODO: naming. it's after the "application logic", more like Controller
 # Currently reusing End.fail_fast as a "something went wrong, but it wasn't a real application error!"


    class Adapter < Trailblazer::Activity::Path
      def self.run_matcher(wrap_ctx, original_args)
        ctx, flow_options = wrap_ctx[:return_args]

        matcher_value = flow_options[:matcher_value]

        outcome = wrap_ctx[:return_signal].to_h[:semantic]

        # Execute the literal block from the controller action.
        matcher_value.call(outcome, [ctx, ctx.to_h]).inspect # DISCUSS: this shouldn't mutate anything.

        return [wrap_ctx, original_args]
      end

      # Build the simplest Adapter possible: run the Protocol and, by leveraging its taskWrap,
      # run the respective matcher block.
      # Note that you could add additional paths and steps here. Let's see what turns out to be useful.
      #
      # The point of running the protocol/business logic in a step, then the matcher block, and then still returning a signal is
      # so we can include this into another activity (e.g. workflow).
      def self.build(protocol)
        Class.new(Adapter) do
          step Subprocess(protocol, strict: true), # FIXME: are we connecting all outputs?
            Extension() => Trailblazer::Activity::TaskWrap::Extension::WrapStatic(
              [Adapter.method(:run_matcher), id: "endpoint.run_matcher", append: "task_wrap.call_task"],
            ),
            Output(:not_found) => Track(:success),
            Output(:not_authenticated) => Track(:success),
            Output(:not_authorized) => Track(:success) # FIXME: what goes here?

            # DISCUSS: in a "traditional" adapter, this one block-executing step would just be one step, and then
            #          we'd just go on the "not_authenticated" path or whatever.
        end
      end
    end # Adapter
  end
end
