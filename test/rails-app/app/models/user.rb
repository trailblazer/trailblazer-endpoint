class User < Struct.new(:id, :email)
  def self.find_by(id: false, email: false)
    return User.new(1, "yogi@trb.to") if email == "yogi@trb.to"
    return User.new(id, "yogi@trb.to") if id.to_s == "1"
    return User.new(id, "seuros@trb.to") if id.to_s == "2"
  end
end
