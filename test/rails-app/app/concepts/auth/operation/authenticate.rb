# FIXME: this is not final, yet!
class Auth::Operation::Authenticate < Trailblazer::Activity::Railway
  step :verify_token
  step :is_token_expired?
  step :set_current_user

  def verify_token(ctx, request:, **)
    auth_header = request.headers['Authorization'] || ""
    jwt_encoded_token = auth_header.split(' ').last
    ctx[:encoded_jwt_token] = jwt_encoded_token

      # FIXME
    #raise StandardError if JwtService.expired?(jwt_encoded_token)
    ctx[:decoded_jwt_token] = Auth::Jwt.decode(jwt_encoded_token)
  end

  def is_token_expired?(ctx, decoded_jwt_token:, **)
    expiration_integer = decoded_jwt_token.first['exp']
    return false if expiration_integer.nil?
    return false if (expiration_integer - DateTime.now.to_i) <= 0
    return true
  end

  def set_current_user(ctx, decoded_jwt_token:, **)
    user_id = decoded_jwt_token.first['user_id']

    ctx[:current_user] = User.find_by(
      id: user_id
    )
    true # FIXME
  end
end
