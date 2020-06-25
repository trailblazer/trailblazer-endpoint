require "minitest/autorun"
require "trailblazer/activity/dsl/linear"
require "trailblazer/activity/testing"
require "trailblazer/developer"

require "trailblazer/endpoint"
require "trailblazer/endpoint/protocol"

require "test_helper"

Minitest::Spec.class_eval do
  T = Trailblazer::Activity::Testing

end
