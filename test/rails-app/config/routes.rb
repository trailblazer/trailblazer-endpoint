Rails.application.routes.draw do
  post "/memos", to: "memos#create"
  get "/memos/:id", to: "memos#show", as: :memo

  post "/no/a", to: "no_protocol_test/a/memos#create"
  post "/no/b", to: "no_protocol_test/b/memos#create"

  post "/a", to: "memo_controller_test/a/memos#create"
  post "/aa", to: "memo_controller_test/aa/memos#create"
  post "/b", to: "memo_controller_test/b/memos#create"
  post "/c", to: "memo_controller_test/c/memos#update"
  post "/c_inherited", to: "memo_controller_test/c/memos#with_inherited_404_handler"
  post "/d", to: "memo_controller_test/d/memos#update"
  post "/d_create", to: "memo_controller_test/d/memos#create"
  post "/dd", to: "memo_controller_test/dd/memos#create"
  post "/e", to: "memo_controller_test/e/memos#create"
  post "/e_admin", to: "memo_controller_test/e/memos#create_with_admin"
  post "/f", to: "memo_controller_test/f/memos#update"
  post "/f_with_runtime_variables", to: "memo_controller_test/f/memos#update_with_runtime_variables"
  post "/g", to: "memo_controller_test/g/memos#update"
  post "/h", to: "memo_controller_test/h/memos#create"
  post "/i", to: "memo_controller_test/i/memos#create"
end
