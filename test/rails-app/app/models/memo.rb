class Memo < Struct.new(:id, :text)
  def self.find_by(id: false)
    return unless id
    return Memo.new(id)
  end

  def self.create(attrs)
    Memo.new(**attrs)
  end
end
