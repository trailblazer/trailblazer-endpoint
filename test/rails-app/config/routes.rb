Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  resources :songs
  post "/songs/create_with_options", to: "songs#create_with_options"
  post "/songs/create_with_or", to: "songs#create_with_or"
  post "/songs/create_with_protocol_failure", to: "songs#create_with_protocol_failure"
  post "/auth/sign_in", to: "auth#sign_in"

  post "/v1/songs", to: "api/v1/songs#create"
  get "/v1/songs/:id", to: "api/v1/songs#show"

  get "/v1/songs_with_options/:id", to: "api/v1/songs_controller/with_options#show"

  get "/", to: "home#dashboard"
end
