Rails.application.routes.draw do
  post "/memos", to: "memos#create"
  get "/memos/:id", to: "memos#show", as: :memo

  post "/a", to: "memo_controller_test/a/memos#create"
  post "/b", to: "memo_controller_test/b/memos#create"
  post "/c", to: "memo_controller_test/c/memos#update"
  post "/c_inherited", to: "memo_controller_test/c/memos#with_inherited_404_handler"
  post "/d", to: "memo_controller_test/d/memos#update"
end
