Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  resources :songs
  post "/songs/create_with_options", to: "songs#create_with_options"
  post "/songs/create_with_or", to: "songs#create_with_or"
end
