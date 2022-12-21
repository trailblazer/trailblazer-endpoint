require "test_helper"

class AlbumApiTest < Minitest::Spec
  include Rack::Test::Methods

  def app
    APP_API
  end

  it "not_authenticated" do
    get "/v1/albums", {}, 'HTTP_AUTHORIZATION' => encode_basic_auth('admin', 'wrong')

    assert_equal last_response.status, 401
    assert_equal last_response.body, "{\"json\":\"Authentication credentials were not provided or are invalid.\"}"
  end

  it "not_authorized" do
    get "/v1/albums", {}, 'HTTP_AUTHORIZATION' => encode_basic_auth('not_admin', 'not_admin')

    assert_equal last_response.status, 403
    assert_equal last_response.body, "{\"json\":\"Action not allowed due to a policy setting.\"}"
  end

  it "success" do
    get "/v1/albums", {}, 'HTTP_AUTHORIZATION' => encode_basic_auth('admin', 'admin')

    assert_equal last_response.status, 200
    # assert_equal last_response.body, "" # TODO: Use representer
  end

  it "created" do
    post "/v1/albums/1/songs", {}, 'HTTP_AUTHORIZATION' => encode_basic_auth('admin', 'admin')

    assert_equal last_response.status, 201
    assert_equal JSON.parse(last_response.body), {"json"=>"{\"id\":1,\"album_id\":\"1\",\"created_by\":\"current_user.username\"}"}
  end
end
