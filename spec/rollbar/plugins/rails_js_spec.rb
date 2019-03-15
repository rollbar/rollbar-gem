require 'spec_helper'

describe ApplicationController, :type => 'request' do
  shared_examples 'adds the snippet' do
    it 'renders the snippet and config in the response', :type => 'request' do
      get '/test_rollbar_js'

      snippet_from_submodule = File.read(File.expand_path('../../../../rollbar.js/dist/rollbar.snippet.js', __FILE__))

      expect(response.body).to include("var _rollbarConfig = #{Rollbar.configuration.js_options.to_json};")
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
    include_examples 'adds the snippet'
  end

  context 'using rails5 content_security_policy',
          :if => (Gem::Version.new(Rails.version) >= Gem::Version.new('5.2.0')) do
    def configure_csp(mode)
      Rails.application.config.content_security_policy_nonce_generator = lambda { |_| SecureRandom.base64(16) }
      if mode == :nonce_present
        nonce_present
      elsif mode == :script_src_not_present
        script_src_not_present
      elsif mode == :unsafe_inline
        unsafe_inline
      else
        raise 'Unknown CSP mode'
      end
    end

    def nonce_present
      # Rails will add the nonce to script_src automatically, when script_src is present.
      Rails.application.config.content_security_policy do |policy|
        policy.script_src :self, :https
      end
    end

    def script_src_not_present
      # This is a valid policy, but Rails will not apply the nonce to script_src.
      Rails.application.config.content_security_policy do |policy|
        policy.default_src :self, :https
        policy.script_src nil
      end
    end

    def unsafe_inline
      # Browser behavior is undefined when unsafe_inline and the nonce are both present.
      # The app should never set both, but if they do, our best behavior is to not use the nonce.
      Rails.application.config.content_security_policy do |policy|
        policy.script_src :self, :unsafe_inline
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

        expect(response.body).to_not include %[<script type="text/javascript" nonce="#{nonce(response)}">]
        expect(response.body).to include '<script type="text/javascript">'
      end

      include_examples 'adds the snippet'
    end

    context 'when unsafe_inline is present' do
      let(:nonce_mode) { :unsafe_inline }

      it 'renders the snippet and config in the response with nonce in script tag' do
        get '/test_rollbar_js'

        expect(response.body).to_not include %[<script type="text/javascript" nonce="#{nonce(response)}">]
        expect(response.body).to include '<script type="text/javascript">'
      end

      include_examples 'adds the snippet'
    end

    context 'when scp nonce is present' do
      let(:nonce_mode) { :nonce_present }

      it 'renders the snippet and config in the response with nonce in script tag' do
        get '/test_rollbar_js'

        expect(response.body).to include %[<script type="text/javascript" nonce="#{nonce(response)}">]
        expect(response.body).to_not include '<script type="text/javascript">'
      end

      include_examples 'adds the snippet'
    end
  end
end
