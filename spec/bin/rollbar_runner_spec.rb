require 'spec_helper'
require 'rails/rollbar_runner'

DUMMYAPP_DIR = File.expand_path('../../dummyapp', __FILE__)

def with_dummyapp_dir(&block)
  FileUtils.cd(DUMMYAPP_DIR) do
    yield
  end
end

describe Rails::RollbarRunner do
  context 'with file contains define method in top level' do
    # refs: https://github.com/rollbar/rollbar-gem/issues/273

    before do
      with_dummyapp_dir do
        File.open('./lib/test_ruunner.rb', 'w') do |file|
          file.write <<-EOS
def hello
  puts 'world'
end

hello
EOS
        end
      end
    end

    it 'do not raise exceptions' do
      with_dummyapp_dir do
        expect( `rollbar-rails-runner ./lib/test_ruunner.rb` ).to eq "world\n"
      end
    end
  end
end
