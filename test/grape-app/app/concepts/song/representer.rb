class Song::Representer < Representable::Decorator
  include Representable::JSON

  property :id
  property :album_id
  property :created_by
end
