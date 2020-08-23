class User < Struct.new(:id, :email)
  def self.find_by(id:)
    return User.new(id, "yogi@trb.to") if id.to_s == "1"
  end
end
