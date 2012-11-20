require 'net/https'
require 'socket'
require 'uri'

require 'ratchetio/version'
require 'ratchetio/configuration'
require 'ratchetio/railtie'

module Ratchetio
  class << self
    attr_writer :configuration
    
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def report_exception(exception, request_data = nil, person_data = nil)
      filtered_level = configuration.exception_level_filters[exception.class.name]
      if filtered_level == 'ignore'
        # ignored - do nothing
        return
      end

      data = exception_data(exception, filtered_level)
      data[:request] = request_data if request_data
      data[:person] = person_data if person_data

      payload = build_payload(data)
      send_payload(payload)
    rescue => e
      logger.error "[Ratchet.io] Error reporting exception to Ratchet.io: #{e}"
    end

    def report_message(message, level = 'info', extra_data = {})
      data = base_data(level)
      
      data[:body] = {
        :message => {
          :body => message.to_s
        }
      }
      data[:body][:message].merge!(extra_data)
      data[:server] = server_data
      
      payload = build_payload(data)
      send_payload(payload)
    rescue => e
      logger.error "[Ratchet.io] Error reporting message to Ratchet.io: #{e}"
    end

    private

    def exception_data(exception, force_level = nil)
      data = base_data
      
      if force_level
        data[:level] = force_level
      end

      # parse backtrace
      frames = []
      exception.backtrace.each { |frame|
        # parse the line
        match = frame.match(/(.*):(\d+)(?::in `([^']+)')?/)
        frames.push({ :filename => match[1], :lineno => match[2].to_i, :method => match[3] })
      }
      # reverse so that the order is as ratchet expects
      frames.reverse!

      data[:body] = {
        :trace => {
          :frames => frames,
          :exception => {
            :class => exception.class.name,
            :message => exception.message
          }
        }
      }

      data[:server] = server_data
      
      data
    end

    def logger
      configuration.logger
    end

    def send_payload(payload)
      logger.info '[Ratchet.io] Sending payload'

      uri = URI.parse(configuration.endpoint)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = payload
      response = http.request(request)

      if response.code == '200'
        logger.info '[Ratchet.io] Success'
      else
        logger.warn "[Ratchet.io] Got unexpected status code from Ratchet.io api: #{response.code}"
        logger.info "[Ratchet.io] Response: #{response.body}"
      end
    end

    def build_payload(data)
      payload = {
        :access_token => configuration.access_token,
        :data => data
      }
      ActiveSupport::JSON.encode(payload)
    end

    def base_data(level = 'error')
      config = configuration
      {
        :timestamp => Time.now.to_i,
        :environment => config.environment,
        :level => level,
        :language => 'ruby',
        :framework => config.framework,
        :notifier => {
          :name => 'ratchetio-gem',
          :version => VERSION
        }
      }
    end

    def server_data
      config = configuration
      
      data = {
        :host => Socket.gethostname
      }
      data[:root] = config.root.to_s if config.root
      data[:branch] = config.branch if config.branch
      
      data
    end
  
  end
end

