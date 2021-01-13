Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  post "/songs/create_with_options", to: "songs_controller/create_with_options#create"
  post "/songs/create_or", to: "songs_controller/create_or#create"
  post "/songs/endpoint_ctx", to: "songs_controller/create_endpoint_ctx#create"
  post "/songs/create_with_or", to: "songs#create"
  post "/songs", to: "songs#create_without_block"
  post "/songs/create_with_protocol_failure", to: "songs_controller/create_with_protocol_failure#create_with_protocol_failure"
  post "/songs/create_with_options_for_domain_ctx", to: "songs_controller/create_with_options_for_domain_ctx#create"
  post "/auth/sign_in", to: "auth#sign_in"

  post "/v1/songs", to: "api/v1/songs#create"
  get "/v1/songs/:id", to: "api/v1/songs#show"

  get "/v1/songs_with_options/:id", to: "api/v1/songs_controller/with_options#show"

  get "/", to: "home#dashboard"

  post "/songs/serialize", to: "songs_controller/serialize#create"
  post "/songs/copy_from_domain_ctx", to: "songs_controller/create1#create"
  post "/songs/serialize1", to: "songs_controller/serialize1#create"
  post "/songs/serialize2", to: "songs_controller/serialize2#create"
  post "/songs/serialize3", to: "songs_controller/serialize3#create"
  post "/songs/serialize4", to: "songs_controller/serialize4#create"
  post "/songs/serialize5", to: "songs_controller/serialize5#create"
  post "/songs/serialize6", to: "songs_controller/serialize6#create"
  post "/songs/serialize7", to: "songs_controller/serialize7#create"
  post "/songs/serialize72", to: "songs_controller/serialize7#new"
end
