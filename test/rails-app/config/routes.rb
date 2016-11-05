Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  resources :songs
  post "update_with_user", to: "songs#update_with_user"
  post "create_with_custom_handlers", to: "songs#create_with_custom_handlers"
end
