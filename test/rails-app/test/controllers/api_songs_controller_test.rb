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
  def get_json(endpoint, params = nil, api_token = nil)
    get endpoint, params: params, headers: request_headers(api_token)
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


  test "API interface" do
    yogi_jwt = jwt(1)

  # default {success}
    #:success
    post_json "/v1/songs", {id: 1}, yogi_jwt

    assert_response 200
    assert_equal "{\"id\":1}", response.body
    #:success end

    # no proper input/params
    post_json "/v1/songs", {}, yogi_jwt
  # default {failure}
    assert_response 422
    assert_equal "{\"errors\":{\"message\":\"The submitted data is invalid.\"}}", response.body

  # 401
    #:not_authenticated
    post_json "/v1/songs", {} # no token
    assert_response 401
    assert_equal "{\"errors\":{\"message\":\"Authentication credentials were not provided or are invalid.\"}}", response.body
    #:not_authenticated end

  # 403
    post_json "/v1/songs", {id: 1, policy: false}, yogi_jwt
    assert_response 403
    assert_equal "{\"errors\":{\"message\":\"Action not allowed due to a policy setting.\"}}", response.body

  # 200 / GET
    get_json "/v1/songs/1", {}, yogi_jwt
    assert_response 200
    assert_equal "{\"id\":\"1\"}", response.body

  # 404
    get_json "/v1/songs/0", {}, yogi_jwt
    assert_response 404
    assert_equal "{\"errors\":{}}", response.body

  # TODO: CHANGE/customize block
  end

  test "allows overriding {:success_block} and friends" do
    yogi_jwt = jwt(1)

  # Not authenticated, 401, overridden {:protocol_failure_block} kicks in
    get_json "/v1/songs_with_options/1"
    assert_response 402

  # All good, default block
    get_json "/v1/songs_with_options/1", yogi_jwt

  end
end

# TODO: test 404 with NotFound config
