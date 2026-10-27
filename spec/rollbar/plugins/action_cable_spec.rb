require 'spec_helper'

# ActionCable rescues every exception raised while it handles a client command
# (ActionCable::Connection::Subscriptions#execute_command) or a connection
# lifecycle event (ActionCable::Server::Worker#invoke), logs it and moves on, so
# nothing reaches Rack, the Rails error reporter or Rollbar.
# See https://github.com/rollbar/rollbar-gem/issues/894
#
# These examples drive a real connection through ActionCable's own worker, the
# same path a production WebSocket message takes, and look at what Rollbar
# actually reported.
describe 'Rollbar ActionCable plugin',
         :if => Gem::Version.new(Rails.version) >= Gem::Version.new('6.0') do
  let(:channel_class) do
    Class.new(ActionCable::Channel::Base) do
      def subscribed
        raise ArgumentError, 'subscribed failed' if params[:fail] == 'subscribed'
      end

      def unsubscribed
        raise ArgumentError, 'unsubscribed failed' if params[:fail] == 'unsubscribed'
      end

      def speak(_data)
        raise ArgumentError, 'speak failed'
      end
    end
  end

  let(:connection_class) do
    Class.new(ActionCable::Connection::Base) do
      def connect
        raise ArgumentError, 'connect failed' if request.params['fail'] == 'connect'
      end

      def disconnect
        raise ArgumentError, 'disconnect failed' if request.params['fail'] == 'disconnect'
      end
    end
  end

  let(:server) { ActionCable.server }
  let(:path) { '/cable?api_key=secret-key' }
  let(:connection) do
    connection_class.new(server, Rack::MockRequest.env_for("http://example.com#{path}"))
  end
  let(:websocket) do
    double('websocket', :alive? => true, :possible? => true,
                        :protocol => 'actioncable-v1-json',
                        :transmit => nil, :close => nil)
  end

  before do
    # Subscriptions look channels up by name; the context uses the class names.
    stub_const('RollbarSpecChannel', channel_class)
    stub_const('RollbarSpecConnection', connection_class)

    reconfigure_notifier
    Rollbar.last_report = nil

    # No real socket is attached in a spec; everything else is ActionCable's.
    allow(connection).to receive(:websocket).and_return(websocket)
  end

  after { Rollbar.last_report = nil }

  def identifier(params = {})
    ActiveSupport::JSON.encode({ :channel => 'RollbarSpecChannel' }.merge(params))
  end

  # The way ActionCable runs every connection callback: on its worker pool,
  # which rescues and logs anything that escapes.
  def invoke(method, *args)
    server.worker_pool.invoke(connection, method, *args, :connection => connection)
  end

  def send_command(payload)
    invoke(:dispatch_websocket_message, ActiveSupport::JSON.encode(payload))
  end

  def subscribe(params = {})
    send_command('command' => 'subscribe', 'identifier' => identifier(params))
  end

  def reported_exception
    report = Rollbar.last_report
    report && report[:body][:trace][:exception]
  end

  shared_examples 'a reported ActionCable error' do |message, context|
    it 'reports the exception to Rollbar' do
      trigger.call

      expect(reported_exception).to eq(:class => 'ArgumentError', :message => message)
    end

    it 'sets the context to the channel or connection callback' do
      trigger.call

      expect(Rollbar.last_report[:context]).to eq(context)
    end

    it 'includes the WebSocket upgrade request, scrubbed' do
      trigger.call

      request = Rollbar.last_report[:request]
      expect(request[:url]).to start_with('http://example.com/cable')
      expect(request[:GET]['api_key']).to match(/\A\*+\z/)
    end

    it 'still lets ActionCable log and handle the error as before' do
      allow(server.logger).to receive(:error).and_call_original

      trigger.call

      expect(server.logger).to have_received(:error).with(/#{message}/).at_least(:once)
    end
  end

  context 'when a channel raises in #subscribed' do
    let(:trigger) { proc { subscribe(:fail => 'subscribed') } }

    it_behaves_like 'a reported ActionCable error', 'subscribed failed',
                    'RollbarSpecChannel#subscribe'
  end

  context 'when a channel action raises' do
    let(:trigger) do
      proc do
        subscribe
        send_command('command' => 'message', 'identifier' => identifier,
                     'data' => ActiveSupport::JSON.encode('action' => 'speak'))
      end
    end

    it_behaves_like 'a reported ActionCable error', 'speak failed',
                    'RollbarSpecChannel#speak'
  end

  context 'when a channel raises in #unsubscribed after an unsubscribe command' do
    let(:trigger) do
      proc do
        subscribe(:fail => 'unsubscribed')
        send_command('command' => 'unsubscribe',
                     'identifier' => identifier(:fail => 'unsubscribed'))
      end
    end

    it_behaves_like 'a reported ActionCable error', 'unsubscribed failed',
                    'RollbarSpecChannel#unsubscribe'
  end

  context 'when a channel raises in #unsubscribed because the client went away' do
    let(:trigger) do
      proc do
        subscribe(:fail => 'unsubscribed')
        invoke(:handle_close)
      end
    end

    it_behaves_like 'a reported ActionCable error', 'unsubscribed failed',
                    'RollbarSpecConnection#disconnect'
  end

  context 'when the connection raises in #connect' do
    let(:path) { '/cable?api_key=secret-key&fail=connect' }
    let(:trigger) { proc { invoke(:handle_open) } }

    it_behaves_like 'a reported ActionCable error', 'connect failed',
                    'RollbarSpecConnection#connect'
  end

  context 'when the connection raises in #disconnect' do
    let(:path) { '/cable?api_key=secret-key&fail=disconnect' }
    let(:trigger) { proc { invoke(:handle_close) } }

    it_behaves_like 'a reported ActionCable error', 'disconnect failed',
                    'RollbarSpecConnection#disconnect'
  end

  context 'when the connection rejects an unauthorized client' do
    let(:connection_class) do
      Class.new(ActionCable::Connection::Base) do
        def connect
          reject_unauthorized_connection
        end
      end
    end

    it 'does not report anything' do
      invoke(:handle_open)

      expect(Rollbar.last_report).to be_nil
    end
  end

  context 'when nothing fails' do
    it 'does not report anything' do
      subscribe
      send_command('command' => 'unsubscribe', 'identifier' => identifier)
      invoke(:handle_close)

      expect(Rollbar.last_report).to be_nil
    end
  end

  context 'when the connection handles the error with rescue_from',
          :if => ActionCable::Connection::Base.respond_to?(:rescue_from) do
    let(:connection_class) do
      Class.new(ActionCable::Connection::Base) do
        attr_reader :rescued

        rescue_from ArgumentError, :with => :handle_argument_error

        private

        def handle_argument_error(exception)
          @rescued = exception
        end
      end
    end

    it 'leaves it to the handler and does not report it' do
      subscribe(:fail => 'subscribed')

      expect(connection.rescued).to be_a(ArgumentError)
      expect(Rollbar.last_report).to be_nil
    end
  end

  context 'when disabled in config' do
    subject { Rollbar.plugins.get('action_cable') }

    before do
      subject.unload!

      # configure loads every plugin after applying the config.
      Rollbar.configure { |c| c.disable_action_cable_monkey_patch = true }
    end

    after do
      Rollbar.configure { |c| c.disable_action_cable_monkey_patch = false }
    end

    it "isn't loaded" do
      expect(subject.loaded).to eq(false)
    end
  end
end
