require 'socket'

class Socket
  def as_json
    to_s
  end
end
