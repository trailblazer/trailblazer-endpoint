require "test_helper"

class SongsControllerTest < ActionDispatch::IntegrationTest
  test "all possible outcomes with {Create}" do
  # 401
    post "/songs", params: {}
    assert_response 401
    assert_equal "", response.body

  # sign in
    post "/auth/sign_in", params: {username: "yogi@trb.to", password: "secret"}
    assert_equal 1, session[:user_id]
    # follow_redirect!
    assert_equal 1, session[:user_id]

    post "/songs", params: {id: 1}
  # default {success} block doesn't do anything
    assert_response 200
    assert_equal "", response.body

    post "/songs", params: {}
  # default {failure} block doesn't do anything
    assert_response 422
    assert_equal "", response.body

  # 403
    post "/songs", params: {policy: false}
    assert_response 403
    assert_equal "", response.body

    post "/songs/create_with_options", params: {id: 1}
  # {success} block renders model
    assert_response 200
    assert_equal "<div>#<struct Song id=\"1\">#<struct User id=2, email=\"seuros@trb.to\"></div>\n", response.body

    post "/songs/create_with_options", params: {}
  # default {failure} block doesn't do anything
    assert_response 422
    assert_equal "", response.body

    post "/songs/create_with_or", params: {id: 1}
  # {success} block renders model
    assert_response 200
    assert_equal "<div>#<struct Song id=\"1\">#<struct User id=1, email=\"yogi@trb.to\"></div>\n", response.body

    post "/songs/create_with_or", params: {}
    assert_response 200
    assert_equal %{<div>#<struct errors=nil></div>\n}, response.body

  # Or { render status: 422 }
    post "/songs/create_or", params: {}
    assert_response 422
    assert_equal %{null}, response.body

  # {:endpoint_ctx} is available in blocks
    post "/songs/endpoint_ctx", params: {id: 1}
    assert_response 200
    assert_equal "Created", response.body
    # assert_equal "[\"domain_ctx\",\"session\",\"controller\",\"config_source\",\"current_user\",\"domain_activity_return_signal\"]", response.body

    # {:options_for_domain_ctx} overrides domain_ctx
    post "/songs/create_with_options_for_domain_ctx", params: {id: 1} # params get overridden
    assert_response 200
    assert_equal "<div>#<struct Song id=999></div>\n", response.body
  end

  test "override protocol_failure" do
    post "/songs/create_with_protocol_failure", params: {}
    assert_response 500
    assert_equal "wrong login, app crashed", response.body
  end

  test "serializing" do
  # # 401
  #   post "/songs/serialize/"
  #   assert_response 401

  # sign in
    post "/auth/sign_in", params: {username: "yogi@trb.to", password: "secret"}
    assert_equal 1, session[:user_id]


  # When {:encrypted_resume_data} is {nil} the entire deserialize cycle is skipped.
  # Nothing gets serialized.
    post "/songs/serialize1/", params: {} # encrypted_resume_data: nil
    assert_response 200
    assert_equal "false/nil/", response.body

  # Nothing deserialized, but {:remember} serialized
  # "confirm_delete form"
    post "/songs/serialize2/", params: {} # {:remember} serialized
    assert_response 200
    encrypted_string = "0109C4E535EDA2CCE8CD69E50C179F5950CC4A2A898504F951C995B6BCEAFE1D77252DBFA014052D"
    assert_equal "false/nil/#{encrypted_string}", response.body

  # {:remember} deserialized
  # "submit confirm_delete"
    post "/songs/serialize3/", params: {encrypted_resume_data: encrypted_string} # {:remember} serialized
    assert_response 200
    assert_equal "false/{\"remember\"=>\"#<OpenStruct id=1>\"}/", response.body
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
