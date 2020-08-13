require "test_helper"

class SongsControllerTest < ActionController::TestCase
  test "create 200" do
    get :create, params: { id: 1 }
    assert_equal 200, response.status
  end
end
