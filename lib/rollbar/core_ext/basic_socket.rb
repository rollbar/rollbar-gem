require 'socket'

class BasicSocket
  def as_json
    to_s
  end
end
