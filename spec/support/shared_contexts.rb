shared_context 'reconfigure notifier for rails', :reconfigure_notifier_for_rails => true do
  before { reconfigure_notifier_for_rails }
end

shared_context 'reconfigure notifier', :reconfigure_notifier => true do
  before { reconfigure_notifier }
end

shared_context 'payload from fixture', :fixture => :payload do
  let(:payload) do
    {
      'data' => load_payload_fixture(payload_fixture),
      'access_token' => 'the-token'
    }
  end
end
