require 'representable'

class Album::Representer < Representable::Decorator
  include Representable::JSON

  property :id
end
