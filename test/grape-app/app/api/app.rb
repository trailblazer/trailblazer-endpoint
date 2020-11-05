module App
  class API < Grape::API
    mount V1::API => "/v1"
  end
end
