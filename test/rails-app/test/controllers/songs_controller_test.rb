require "test_helper"

class SongsControllerTest < ActionController::TestCase
  test "show 200" do
    get :show, params: { id: 1 }
    assert_equal 200, response.status
  end
end
