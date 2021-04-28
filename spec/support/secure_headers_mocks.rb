module SecureHeadersMocks
  NONCE = 'lorem-ipsum-nonce'.freeze
  NONCE_KEY = 'secure_headers_content_security_policy_nonce'.freeze

  module CSP
    class << self
      attr_accessor :config

      def opt_out?
        config[:opt_out?]
      end

      def [](key)
        config[key]
      end
    end
  end

  module SecureHeaders20
  end

  module SecureHeaders30
    NONCE_KEY = SecureHeadersMocks::NONCE_KEY
    OPT_OUT = :opt_out
    class << self
      def content_security_policy_script_nonce(_req)
        NONCE
      end
    end

    module Configuration
      module CSPProxy
        def self.csp
          return OPT_OUT if CSP.opt_out?

          CSP.config
        end
      end

      def self.get
        CSPProxy
      end
    end
  end

  module SecureHeaders35
    NONCE_KEY = SecureHeadersMocks::NONCE_KEY
    class << self
      def content_security_policy_script_nonce(_req)
        NONCE
      end
    end

    module Configuration
      module CSPProxy
        def self.csp
          CSP
        end
      end

      def self.get
        CSPProxy
      end
    end
  end

  module SecureHeaders60
    NONCE_KEY = SecureHeadersMocks::NONCE_KEY
    class << self
      def content_security_policy_script_nonce(_req)
        NONCE
      end
    end

    module Configuration
      module CSPProxy
        def self.csp
          CSP
        end
      end

      def self.dup
        CSPProxy
      end
    end
  end
end
