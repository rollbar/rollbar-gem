require 'spec_helper'

describe ApplicationController, :type => 'request' do
  def reset_secure_headers_config
    return unless defined?(::SecureHeaders)

    config = ::SecureHeaders::Configuration.new do |config|
      config.csp = SecureHeaders::OPT_OUT
      config.hsts = SecureHeaders::OPT_OUT
      config.x_frame_options = SecureHeaders::OPT_OUT
      config.x_content_type_options = SecureHeaders::OPT_OUT
      config.x_xss_protection = SecureHeaders::OPT_OUT
      config.x_permitted_cross_domain_policies = SecureHeaders::OPT_OUT
    end

    ::SecureHeaders::Configuration.instance_variable_set(:@default_config, config)
  end

  shared_examples 'adds the snippet' do
    it 'renders the snippet and config in the response', :type => 'request' do
      get '/test_rollbar_js'

      snippet_from_submodule = File.read(
        File.expand_path('../../../../rollbar.js/dist/rollbar.snippet.js', __FILE__))

      expect(response.body).to include(
        "var _rollbarConfig = #{Rollbar.configuration.js_options.to_json};"
      )
      expect(response.body).to include(snippet_from_submodule)
    end
  end

  before do
    Rollbar.configure do |config|
      config.js_options = { :foo => :bar }
      config.js_enabled = true
    end
  end

  context 'using no security policy' do
    before(:all) do
      reset_secure_headers_config # disable secure_headers gem
    end

    include_examples 'adds the snippet'
  end

  context 'using rails5 content_security_policy',
          :if => (Gem::Version.new(Rails.version) >= Gem::Version.new('5.2.0')) do
    def configure_csp(mode)
      if mode == :nonce_present
        nonce_present
      elsif mode == :nonce_not_present
        nonce_not_present
      elsif mode == :script_src_not_present
        script_src_not_present
      elsif mode == :unsafe_inline_present
        unsafe_inline_present
      else
        raise 'Unknown CSP mode'
      end
    end

    def nonce_present
      # Rails will add the nonce to script_src when the generator is set.
      Rails.application.config.content_security_policy_nonce_generator = lambda { |_|
        SecureRandom.base64(16)
      }

      Rails.application.config.content_security_policy do |policy|
        policy.script_src :self, :https
      end
    end

    def nonce_not_present
      Rails.application.config.content_security_policy_nonce_generator = nil

      Rails.application.config.content_security_policy do |policy|
        policy.script_src :self, :https
      end
    end

    def script_src_not_present
      Rails.application.config.content_security_policy_nonce_generator = lambda { |_|
        SecureRandom.base64(16)
      }

      # This is a valid policy, but Rails will not apply the nonce to script_src.
      Rails.application.config.content_security_policy do |policy|
        policy.default_src :self, :https
        policy.script_src nil
      end
    end

    def unsafe_inline_present
      # Rails will add the nonce to script_src when the generator is set.
      Rails.application.config.content_security_policy_nonce_generator = lambda { |_|
        SecureRandom.base64(16)
      }

      Rails.application.config.content_security_policy do |policy|
        policy.script_src :unsafe_inline
      end
    end

    def nonce(response)
      response.request.content_security_policy_nonce
    end

    def reset_csp_config
      # Note that the public interface for #content_security_policy only accepts
      # a block, which will always assign an ActionDispatch::ContentSecurityPolicy
      # object. Here we reset to its original state of nil.
      Rails.application.config.instance_variable_set(:@content_security_policy, nil)
      Rails.application.config.content_security_policy_nonce_generator = nil
    end

    def reset_rails_config
      # Load a new Rails config between examples
      #
      # Rails will not read an updated config after app boot, and rspec provides
      # no way to restart the app. Here, we reset the memoized value so the app
      # will read in the new config on the next request.
      Rails.application.instance_variable_set(:@app_env_config, nil)
    end

    before do
      reset_rails_config
      configure_csp(nonce_mode)
    end

    before(:all) do
      reset_secure_headers_config # disable secure_headers gem
    end

    after(:all) do
      # Ensure that later test groups have a clean rails config.
      # CSP settings could interfere with some other tests.
      reset_csp_config
      reset_rails_config
    end

    context 'when script_src is not present' do
      let(:nonce_mode) { :script_src_not_present }

      it 'renders the snippet and config in the response without nonce in script tag' do
        get '/test_rollbar_js'

        expect(response.body)
          .to_not include %[<script type="text/javascript" nonce="#{nonce(response)}">]
        expect(response.body).to include '<script type="text/javascript">'
      end

      include_examples 'adds the snippet'
    end

    context 'when nonce is not present' do
      let(:nonce_mode) { :nonce_not_present }

      it 'renders the snippet and config in the response without nonce in script tag' do
        get '/test_rollbar_js'

        expect(response.body)
          .to_not include %[<script type="text/javascript" nonce="#{nonce(response)}">]
        expect(response.body).to include '<script type="text/javascript">'
      end

      include_examples 'adds the snippet'
    end

    context 'when CSP nonce is present' do
      let(:nonce_mode) { :nonce_present }

      it 'renders the snippet and config in the response with nonce in script tag' do
        get '/test_rollbar_js'

        expect(response.body)
          .to include %[<script type="text/javascript" nonce="#{nonce(response)}">]
        expect(response.body).to_not include '<script type="text/javascript">'
      end

      include_examples 'adds the snippet'
    end

    context 'when CSP nonce and unsafe_inline are present' do
      let(:nonce_mode) { :unsafe_inline_present }

      it 'renders the snippet and config in the response with nonce in script tag' do
        get '/test_rollbar_js'

        expect(response.body)
          .to include %[<script type="text/javascript" nonce="#{nonce(response)}">]
        expect(response.body).to_not include '<script type="text/javascript">'
      end

      include_examples 'adds the snippet'
    end
  end

  context 'using secure_headers',
          :if => (Gem::Version.new(Rails.version) >= Gem::Version.new('5.0.0')) do
    before do
      configure_csp(nonce_mode)
    end

    after do
      reset_secure_headers_config
    end

    def configure_csp(mode)
      return unless defined?(::SecureHeaders)

      if mode == :nonce_present
        nonce_present
      elsif mode == :nonce_not_present
        nonce_not_present
      elsif mode == :unsafe_inline_present
        unsafe_inline_present
      else
        raise 'Unknown CSP mode'
      end
    end

    def nonce_present
      config = ::SecureHeaders::Configuration.new do |config|
        config.csp = {
          :default_src => %w['none'],
          :script_src => %w['self']
        }
      end
      ::SecureHeaders::Configuration.instance_variable_set(:@default_config, config)
    end

    def nonce_not_present
      config = ::SecureHeaders::Configuration.new do |config|
        config.csp = {
          :default_src => %w['none'],
          :script_src => %w['self']
        }
      end
      ::SecureHeaders::Configuration.instance_variable_set(:@default_config, config)
    end

    def unsafe_inline_present
      config = ::SecureHeaders::Configuration.new do |config|
        config.csp = {
          :default_src => %w['none'],
          :script_src => %w['unsafe-inline']
        }
      end
      ::SecureHeaders::Configuration.instance_variable_set(:@default_config, config)
    end

    def nonce(response)
      ::SecureHeaders.content_security_policy_script_nonce(response.request)
    end

    context 'when nonce is not present' do
      let(:nonce_mode) { :nonce_not_present }

      it 'renders the snippet and config in the response without nonce in script tag' do
        get '/test_rollbar_js'

        expect(response.body)
          .to_not include %[<script type="text/javascript" nonce="#{nonce(response)}">]
        expect(response.body).to include '<script type="text/javascript">'
      end

      include_examples 'adds the snippet'
    end

    context 'when nonce is present' do
      let(:nonce_mode) { :nonce_present }

      it 'renders the snippet and config in the response with nonce in script tag' do
        get '/test_rollbar_js_with_nonce'

        expect(response.body)
          .to include %[<script type="text/javascript" nonce="#{nonce(response)}">]
        expect(response.body).to_not include '<script type="text/javascript">'
      end

      include_examples 'adds the snippet'
    end

    context 'when CSP nonce and unsafe_inline are present' do
      let(:nonce_mode) { :unsafe_inline_present }

      it 'renders the snippet and config in the response with nonce in script tag' do
        get '/test_rollbar_js_with_nonce'

        expect(response.body)
          .to include %[<script type="text/javascript" nonce="#{nonce(response)}">]
        expect(response.body).to_not include '<script type="text/javascript">'
      end

      include_examples 'adds the snippet'
    end
  end
end
