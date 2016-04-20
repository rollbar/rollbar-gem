require 'spec_helper'

describe ApplicationController, :type => 'request' do
  before do
    Rollbar.configure do |config|
      config.js_options = { :foo => :bar }
      config.js_enabled = true
    end
  end

  it 'renders the snippet and config in the response', :type => 'request' do
    get '/test_rollbar_js'

    snippet_from_submodule = File.read(File.expand_path('../../../../rollbar.js/dist/rollbar.snippet.js', __FILE__))

    expect(response.body).to include("var _rollbarConfig = #{Rollbar::configuration.js_options.to_json};")
    expect(response.body).to include(snippet_from_submodule)
  end
end
