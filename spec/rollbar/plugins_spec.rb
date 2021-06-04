require 'spec_helper'
require 'rollbar/plugins'
require 'rollbar/plugin'

describe Rollbar::Plugins do
  let(:plugin_files_path) do
    File.expand_path('../../fixtures/plugins/**/*.rb', __FILE__)
  end
  let!(:current_plugins) do
    Rollbar.plugins
  end

  let(:plugin1_proc) do
    proc do
      dependency { true }
    end
  end

  before do
    Rollbar.plugins = nil
    allow_any_instance_of(described_class).to receive(:plugin_files)
      .and_return(plugin_files_path)
  end

  after do
    Rollbar.plugins = current_plugins
  end

  describe '#require_all' do
    it 'loads the plugins' do
      expect(Rollbar.plugins).to receive(:define).with(:dummy1)
      expect(Rollbar.plugins).to receive(:define).with(:dummy2)

      subject.require_all
    end
  end

  describe '#define' do
    it 'evals the plugin DSL and adds it to the collection' do
      expect_any_instance_of(Rollbar::Plugin).to receive(:dependency)
      expect do
        subject.define(:name, &plugin1_proc)
      end.to change(subject.collection, :size).by(1)
    end

    context 'with a plugin already defined' do
      it 'doesnt load the plugin twice' do
        subject.define(:name, &plugin1_proc)

        expect_any_instance_of(Rollbar::Plugin).not_to receive(:instance_eval)
        expect do
          subject.define(:name, &plugin1_proc)
        end.to change(subject.collection, :size).by(0)
      end
    end
  end

  describe '#load!' do
    before do
      subject.define(:plugin1, &plugin1_proc)
    end

    it 'calls load! in the plugins' do
      expect_any_instance_of(Rollbar::Plugin).to receive(:load!).once

      subject.load!
    end

    context 'with on demand plugins' do
      before do
        subject.define(:on_demand_plugin) do
          load_on_demand
        end
      end

      it 'it doesn\'t load on demand plugins by default' do
        expect(subject.get(:on_demand_plugin)).to_not receive(:load!)

        subject.load!
      end
    end
  end

  describe '#get' do
    context 'with a defined plugin' do
      before do
        subject.define('#get_plugin', &plugin1_proc)
      end

      it 'finds the plugin' do
        expect(subject.get('#get_plugin')).to be_kind_of(Rollbar::Plugin)
      end
    end
  end
end
