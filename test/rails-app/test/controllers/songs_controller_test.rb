require "test_helper"

class SongsControllerTest < ActionDispatch::IntegrationTest
  test "create 200" do
    post "/songs", params: {id: 1}
  # default {success} block doesn't do anything
    assert_response 200
    assert_equal "", response.body

    post "/songs", params: {}
  # default {failure} block doesn't do anything
    assert_response 422
    assert_equal "", response.body

    post "/songs/create_with_options", params: {id: 1}
  # {success} block renders model
    assert_response 200
    assert_equal "1", response.body

    post "/songs/create_with_options", params: {}
  # default {failure} block doesn't do anything
    assert_response 422
    assert_equal "", response.body

    post "/songs/create_with_or", params: {id: 1}
  # {success} block renders model
    assert_response 200
    assert_equal "{\"or\":\"1\"}", response.body

    post "/songs/create_with_or", params: {}
  # default {failure} block doesn't do anything
    assert_response 422
    assert_equal "null", response.body

  end
end
