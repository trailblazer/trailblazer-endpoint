require "test_helper"

class ApiSongsControllerTest < ActionDispatch::IntegrationTest

  def jwt(user_id)
    Auth::Jwt.generate('user_id', user_id, {}
      # 'email': options['current_user'].email
    )
  end

  def post_json(endpoint, params_hash, api_token = nil, headers={})
    post endpoint, params: params_hash.to_json, headers: request_headers(api_token).merge(headers)
  end
  def request_headers(api_token = nil)
    headers = {
      'Content-Type' => 'application/json'
    }
    unless api_token.nil?
      headers.merge!(authorization_header(api_token))
    end
    headers
  end
  def authorization_header(api_token)
    { 'Authorization' => "Bearer #{api_token}"}
  end


  test "create 200" do
    # raise jwt(1).inspect
    yogi_jwt = jwt(1)

    post_json "/v1/songs", {params: {id: 1}}, yogi_jwt
  # default {success} block doesn't do anything
    assert_response 200
    assert_equal "", response.body

raise
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
    assert_equal "[\"1\",\"yay!\"]", response.body

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

# TODO: test 404 with NotFound config
