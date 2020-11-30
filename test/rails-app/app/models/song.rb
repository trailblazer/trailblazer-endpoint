class Song < Struct.new(:id)
  def self.find_by(id: false)
    return Song.new(id)
  end
end
