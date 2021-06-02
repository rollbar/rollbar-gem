require 'spec_helper'
require 'rollbar/middleware/js'
require 'rollbar/middleware/js/json_value'

shared_examples 'secure_headers' do
  it 'renders the snippet and config in the response with nonce in script tag when SecureHeaders installed' do
    SecureHeadersMocks::CSP.config = {
      :opt_out? => false
    }

    _, _, response = subject.call(env)

    new_body = response.body.join

    expect(new_body).to include('<script type="text/javascript" nonce="lorem-ipsum-nonce">')
    expect(new_body).to include("var _rollbarConfig = #{json_options};")
    expect(new_body).to include(snippet)
  end

  it 'renders the snippet in the response without nonce if SecureHeaders CSP is OptOut' do
    SecureHeadersMocks::CSP.config = {
      :opt_out? => true
    }

    _, _, response = subject.call(env)
    new_body = response.body.join

    expect(new_body).to include('<script type="text/javascript">')
    expect(new_body).to include("var _rollbarConfig = #{json_options};")
    expect(new_body).to include(snippet)
  end
end

describe Rollbar::Middleware::Js do
  subject { described_class.new(app, config) }

  let(:env) { { SecureHeadersMocks::NONCE_KEY => SecureHeadersMocks::NONCE } }
  let(:config) { {} }
  let(:app) do
    proc do |_|
      [status, headers, body]
    end
  end
  let(:html) do
    <<-END
<html>
  <head>
    <link rel="stylesheet" href="url" type="text/css" media="screen" />
    <script type="text/javascript" src="foo"></script>
  </head>
  <body>
    <h1>Testing the middleware</h1>
  </body>
</html>
    END
  end
  let(:minified_html) do
    <<-END
<html><head><link rel="stylesheet" href="url" type="text/css" media="screen" /><script type="text/javascript" src="foo"></script></head><body><h1>Testing the middleware</h1></body></html>
    END
  end
  let(:meta_charset_html) do
    <<-END
<html>
  <head>
    <meta charset="UTF-8"/>
    <link rel="stylesheet" href="url" type="text/css" media="screen" />
    <script type="text/javascript" src="foo"></script>
  </head>
  <body>
    <h1>Testing the middleware</h1>
  </body>
</html>
    END
  end
  let(:meta_content_html) do
    <<-END
<html>
  <head>
    <meta content="origin" id="mref" name="referrer">
    <link rel="stylesheet" href="url" type="text/css" media="screen" />
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
    <script type="text/javascript" src="foo"></script>
  </head>
  <body>
    <h1>Testing the middleware</h1>
  </body>
</html>
    END
  end
  let(:snippet) { 'THIS IS THE SNIPPET' }
  let(:content_type) { 'text/html' }

  before do
    reconfigure_notifier
    allow(subject).to receive(:js_snippet).and_return(snippet)
  end

  let(:config) do
    {
      :enabled => true,
      :options => {
        :foo => :bar,
        :checkIgnore => Rollbar::JSON::Value.new('function(){ alert("bar") }')
      }
    }
  end

  let(:json_options) do
    # MUST use the Ruby JSON encoder (JSON#generate).
    # See lib/rollbar/middleware/js/json_value
    ::JSON.generate(config[:options])
  end

  shared_examples "doesn't add the snippet or config", :add_js => false do
    it "doesn't add the snippet or config" do
      res_status, res_headers, response = subject.call(env)
      new_body = response.join

      expect(new_body).not_to include(snippet)
      expect(new_body).not_to include(json_options)
      expect(new_body).to be_eql(body.join)
      expect(res_status).to be_eql(status)
      expect(res_headers['Content-Type']).to be_eql(content_type)
    end
  end

  describe '#call' do
    context 'with enabled config' do
      context 'having a html 200 response' do
        let(:body) { [html] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end

        it 'adds the config and the snippet to the response' do
          res_status, res_headers, response = subject.call(env)
          new_body = response.body.join

          expect(new_body).to_not include('>>')
          expect(new_body).to include(snippet)
          expect(new_body).to include(json_options)
          expect(res_status).to be_eql(status)
          expect(res_headers['Content-Type']).to be_eql(content_type)
        end
      end

      context 'having a html 200 response with minified body' do
        let(:body) { [minified_html] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end

        it 'adds the config and the snippet to the response' do
          res_status, res_headers, response = subject.call(env)
          new_body = response.body.join

          expect(new_body).to_not include('>>')
          expect(new_body).to include(snippet)
          expect(new_body).to include(json_options)
          expect(res_status).to be_eql(status)
          expect(res_headers['Content-Type']).to be_eql(content_type)
        end
      end

      context 'having a html 200 response with meta charset tag' do
        let(:body) { [meta_charset_html] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end
        it 'adds the config and the snippet to the response' do
          res_status, res_headers, response = subject.call(env)
          new_body = response.body.join

          expect(new_body).to_not include('>>')
          expect(new_body).to include(snippet)
          expect(new_body).to include(json_options)
          expect(res_status).to be_eql(status)
          expect(res_headers['Content-Type']).to be_eql(content_type)
          meta_tag = '<meta charset="UTF-8"/>'
          expect(new_body.index(snippet)).to be > new_body.index(meta_tag)
        end
      end

      context 'having a html 200 response with meta content-type tag' do
        let(:body) { [meta_content_html] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end
        it 'adds the config and the snippet to the response' do
          res_status, res_headers, response = subject.call(env)
          new_body = response.body.join

          expect(new_body).to_not include('>>')
          expect(new_body).to include(snippet)
          expect(new_body).to include(json_options)
          expect(res_status).to be_eql(status)
          expect(res_headers['Content-Type']).to be_eql(content_type)
          meta_tag = '<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>'
          expect(new_body.index(snippet)).to be > new_body.index(meta_tag)
        end
      end

      context 'having a html 200 response and SecureHeaders >= 3.0.0 defined' do
        let(:body) { [html] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end

        before do
          stub_const('::SecureHeaders', secure_headers_mock)
          SecureHeadersMocks::CSP.config = {}
        end

        context 'with secure headers 3.0.x-3.4.x' do
          let(:secure_headers_mock) { SecureHeadersMocks::SecureHeaders30 }

          include_examples 'secure_headers'
        end

        context 'with secure headers 3.5' do
          let(:secure_headers_mock) { SecureHeadersMocks::SecureHeaders35 }

          include_examples 'secure_headers'
        end

        context 'with secure headers 6.0' do
          let(:secure_headers_mock) { SecureHeadersMocks::SecureHeaders60 }

          include_examples 'secure_headers'
        end
      end

      context 'having a html 200 response and SecureHeaders < 3.0.0 defined' do
        let(:body) { [html] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end

        before do
          stub_const('::SecureHeaders', ::SecureHeadersMocks::SecureHeaders20)
        end

        it 'renders the snippet and config in the response without nonce in script tag when too old SecureHeaders installed' do
          _, _, response = subject.call(env)
          new_body = response.body.join

          expect(new_body).to include('<script type="text/javascript">')
          expect(new_body).to include("var _rollbarConfig = #{json_options};")
          expect(new_body).to include(snippet)
        end
      end

      context 'having a html 200 response without head', :add_js => false do
        let(:body) { ['foobar'] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end
      end

      context 'having a html 200 response without head but with an header tag',
              :add_js => false do
        let(:body) { ['<header>foobar</header>'] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end
      end

      context 'having a html 302 response', :add_js => false do
        let(:body) { ['foobar'] }
        let(:status) { 302 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end
      end

      context 'having the js already injected key in env', :add_js => false do
        let(:body) { ['foobar'] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end
        let(:env) do
          { described_class::JS_IS_INJECTED_KEY => true }
        end
      end

      context 'having an attachment', :add_js => false do
        let(:content_type) { 'text/plain' }
        let(:body) { ['foobar'] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Disposition' => 'attachment',
            'Content-Type' => content_type }
        end
      end

      context 'with an exception raised while adding the js', :add_js => false do
        let(:body) { [html] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end

        before do
          allow(subject).to receive(:add_js).and_raise(StandardError.new)
        end
      end

      context 'with person data' do
        let(:body) { [html] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end
        let(:config) do
          {
            :enabled => true,
            :options => { :foo => :bar, :payload => { :a => 42 } }
          }
        end
        let(:env) do
          {
            'rollbar.person_data' => {
              :id => 100,
              :username => 'foo',
              :email => 'foo@bar.com'
            }
          }
        end
        let(:expected_js_options) do
          {
            :foo => 'bar',
            :payload => {
              :a => 42,
              :person => {
                :id => 100,
                :username => 'foo',
                :email => 'foo@bar.com'
              }
            }
          }
        end

        it 'adds the person data to the configuration' do
          _, _, response = subject.call(env)
          new_body = response.body.join

          rollbar_config = new_body[%r{var _rollbarConfig = (.*);</script>}, 1]
          rollbar_config = JSON.parse(rollbar_config, :symbolize_names => true)

          expect(rollbar_config).to eql(expected_js_options)
        end

        context 'when the person data is nil' do
          let(:env) do
            {
              'rollbar.person_data' => nil
            }
          end

          it 'works correctly and doesnt add anything about person data' do
            _, _, response = subject.call(env)
            new_body = response.body.join

            expect(new_body).not_to include('person')
          end

          it 'doesnt include old data when called a second time' do
            subject.call(
              'rollbar.person_data' => {
                :id => 100,
                :username => 'foo',
                :email => 'foo@bar.com'
              }
            )
            _, _, response = subject.call(env)
            new_body = response.body.join

            expect(new_body).not_to include('person')
          end
        end
      end

      context 'json encoding config options' do
        let(:body) { [html] }
        let(:status) { 200 }
        let(:headers) do
          { 'Content-Type' => content_type }
        end
        let(:json_value) do
          Rollbar::JSON::Value.new('function(){ alert("bar") }').to_json
        end

        context 'using Ruby JSON encoder' do
          it 'encodes as native json' do
            expect(json_value).to be_a(String)
          end

          it 'adds the config and the snippet to the response' do
            res_status, res_headers, response = subject.call(env)
            new_body = response.body.join

            expect(new_body).to_not include('>>')
            expect(new_body).to include(snippet)
            expect(new_body).to include(json_options)
            expect(res_status).to be_eql(status)
            expect(res_headers['Content-Type']).to be_eql(content_type)
          end
        end
      end

      context 'having Content-Length previously set' do
        let(:body) { [html] }
        let(:status) { 200 }
        let(:headers) do
          {
            'Content-Type' => content_type,
            'Content-Length' => html.bytesize
          }
        end

        it 'injects the js snippet and updates Content-Length header' do
          res_status, res_headers, response = subject.call(env)
          new_body = response.body.join

          expect(new_body).to_not include('>>')
          expect(new_body).to include(snippet)
          expect(new_body).to include(json_options)
          expect(res_status).to be_eql(status)
          expect(res_headers['Content-Type']).to be_eql(content_type)
          expect(res_headers['Content-Length']).to be_eql(new_body.bytesize.to_s)
        end
      end
    end

    context 'having the config disabled', :add_js => false do
      let(:body) { ['foobar'] }
      let(:status) { 302 }
      let(:headers) do
        { 'Content-Type' => content_type }
      end
      let(:config) do
        {
          :enabled => false,
          :options => { :foo => :bar }
        }
      end
    end

    context 'if the app raises' do
      let(:exception) { StandardError.new }
      let(:app) do
        proc do |_|
          raise exception
        end
      end

      it 'propagates the exception' do
        expect do
          app.call(env)
        end.to raise_exception(exception)
      end
    end
  end
end
