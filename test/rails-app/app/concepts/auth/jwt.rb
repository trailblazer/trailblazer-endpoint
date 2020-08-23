require 'date'
require "jwt"

# Thanks to pocketrocket GmbH for providing this sample code.
module Auth
  class Jwt
    DecodingError = Class.new(StandardError) # FIXME: remove

    # Generate a JWT from arguments
    def self.generate(encoding_key, encoding_value, payload)
      # expiration_time = Rails.application.credentials[:jwt_expiration_time].hours.from_now.to_i # TODO: show how to inject config options
      expiration_time = 1.hours.from_now.to_i
      payload['exp']  = expiration_time
      jwt = JWT.encode(payload,
        Rails.application.credentials[:secret_key_base], 'HS512',
        { exp: expiration_time, encoding_key.to_sym => encoding_value }
      )
      return jwt
    end

    # Validate tokens expiration date
    def self.expired?(token)
      decoded_token = JwtService.decode(token)
      expiry_timestamp = decoded_token.first['exp']
      expiration_date = Time.at(expiry_timestamp).to_datetime
      return DateTime.now > expiration_date
    rescue => err
      return true
    end

    def self.decode(token)
      JWT.decode(token, Rails.application.credentials[:secret_key_base], true, { algorithm: 'HS512'})
    rescue => err
      raise DecodingError.new
    end
  end
end
