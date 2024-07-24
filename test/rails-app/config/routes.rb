Rails.application.routes.draw do
  post "/memos", to: "memos#create"
end
