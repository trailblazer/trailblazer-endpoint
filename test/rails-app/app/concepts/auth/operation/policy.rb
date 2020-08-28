module Auth
  module Operation
    class Policy
      def self.call(ctx, domain_ctx:, **)
        domain_ctx[:params][:policy] == false ? false : true
      end
    end
  end
end
