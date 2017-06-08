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

    it 'do not raise exceptions' do
      Bundler.with_clean_env do
        with_dummyapp_dir do
          expect( `bundle exec rollbar-rails-runner ./lib/test_ruunner_with_define_method_in_top_level.rb` ).to eq "world\n"
        end
      end
    end
  end
end
