module Rollbar
  module Util
    module IPObfuscator
      require 'ipaddr'
      require 'digest'

      def self.obfuscate_ip(ip_string)
        return ip_string unless Rollbar.configuration.user_ip_obfuscator_secret

        secret = Rollbar.configuration.user_ip_obfuscator_secret
        ip_int32 = IPAddr.new(ip_string, Socket::AF_INET).to_i
        secret_int32 = Digest::MD5.hexdigest(secret)[0..7].to_i(16)
        obfuscated_ip_int32 = ip_int32 ^ secret_int32 % (2 << 31)

        IPAddr.new(obfuscated_ip_int32, Socket::AF_INET).to_s
      rescue
        nil
      end
    end
  end
end
