require "test_helper"

class MemoControllerTest < ActionDispatch::IntegrationTest
  test "all possible outcomes with {Create}" do

  # 401
    post "/memos", params: {memo: {}}
    assert_response 401
    assert_equal "", response.body

  end
end
