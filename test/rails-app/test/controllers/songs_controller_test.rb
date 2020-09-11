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

  # 401
    post "/songs", params: {authenticate: false}
    assert_response 401
    assert_equal "", response.body

  # 403
    post "/songs", params: {policy: false}
    assert_response 403
    assert_equal "", response.body

    post "/songs/create_with_options", params: {id: 1}
  # {success} block renders model
    assert_response 200
    assert_equal "[{\"id\":\"1\"},\"yay!\"]", response.body

    post "/songs/create_with_options", params: {}
  # default {failure} block doesn't do anything
    assert_response 422
    assert_equal "", response.body

    post "/songs/create_with_or", params: {id: 1}
  # {success} block renders model
    assert_response 200
    assert_equal "{\"or\":{\"id\":\"1\"}}", response.body

    post "/songs/create_with_or", params: {}
  # default {failure} block doesn't do anything
    assert_response 422
    assert_equal "[\"domain_ctx\",\"controller\",\"config_source\",\"domain_activity_return_signal\"]", response.body

  end

  test "override protocol_failure" do
    post "/songs/create_with_protocol_failure", params: {}
    assert_response 500
  end

  test "sign_in" do
  # wrong credentials
    post "/auth/sign_in", params: {}
    assert_response 401
    assert_equal "", response.body
    assert_nil session[:user_id]

  # valid signin
    post "/auth/sign_in", params: {username: "yogi@trb.to", password: "secret"}
    assert_response 302
    # assert_equal "", response.body
    assert_equal 1, session[:user_id]
    assert_redirected_to "/"
  end
end

# TODO: test 404 with NotFound config
