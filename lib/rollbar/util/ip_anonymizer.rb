module Rollbar
  module Util
    module IPAnonymizer
      require 'ipaddr'

      def self.anonymize_ip(ip_string)
        return ip_string unless Rollbar.configuration.anonymize_user_ip
        
        ip = IPAddr.new(ip_string)
          
        if ip.ipv6?
          return anonymize_ipv6 ip
        end
        
        if ip.ipv4?
          return anonymize_ipv4 ip
        end
        
      rescue
        nil
      end
      
      def self.anonymize_ipv4(ip)
        ip_parts = ip.to_s.split '.'
        
        ip_parts[ip_parts.count-1] = "0"
        
        IPAddr.new(ip_parts.join('.')).to_s
      end
      
      def self.anonymize_ipv6(ip)
        ip_parts = ip.to_s.split ':'
        
        ip_string = ip_parts[0..2].join(':') + ':0000:0000:0000:0000:0000'
        
        IPAddr.new(ip_string).to_s
      end
    end
  end
end
