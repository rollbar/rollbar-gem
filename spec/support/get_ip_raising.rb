class GetIpRaising
  class IpSpoofAttackError < StandardError; end

  def to_s
    raise IpSpoofAttackError, 'spoofing IP!'
  end
end
