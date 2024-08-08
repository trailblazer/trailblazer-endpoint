class Memo < Struct.new(:id, :text, keyword_init: true)
  def self.find_by(id: false)
    return unless id
    return Memo.new(id)
  end

  def self.create(**attrs)
    Memo.new(**attrs.symbolize_keys)
  end
end
