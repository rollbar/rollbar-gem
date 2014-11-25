shared_context 'reconfigure notifier', :reconfigure_notifier => true do
  before { reconfigure_notifier }
end

shared_context 'payload from fixture', :fixture => :payload do
  let(:payload) do
    {
      'data' => load_payload_fixture(payload_fixture).deep_symbolize_keys,
      'access_token' => 'the-token'
    }
  end
end
