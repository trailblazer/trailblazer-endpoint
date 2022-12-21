module V1
  class API < Grape::API
    format :json
    mount V1::Album => "/albums"
  end
end
