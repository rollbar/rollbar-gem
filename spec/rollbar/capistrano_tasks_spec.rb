require 'spec_helper'
require 'rollbar/capistrano_tasks'
require 'capistrano/all'
require 'sshkit'

describe ::Rollbar::CapistranoTasks do
  let(:capistrano) { ::Capistrano::Configuration.new }
  let(:logger) { instance_double(::SSHKit::Backend::Printer) } # this needs to be different for Capistrano 2.x

  let(:rollbar_user) { 'foo' }
  let(:rollbar_comment) { 'bar' }
  let(:rollbar_token) { 'baz' }
  let(:rollbar_env) { 'foobar' }
  let(:rollbar_revision) { 'sha123' }
  let(:dry_run) { false }

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
    allow(logger).to receive(:debug)

    capistrano.set(:rollbar_user, rollbar_user)
    capistrano.set(:rollbar_comment, rollbar_comment)
    capistrano.set(:rollbar_token, rollbar_token)
    capistrano.set(:rollbar_env, rollbar_env)
    capistrano.set(:rollbar_revision, rollbar_revision)

    capistrano.set(:rollbar_deploy_id, nil)
  end

  describe '.deploy_started' do
    context 'when a valid response from the API is received' do
      it 'prints the API request, response, reports the deploy and sets the deploy_id' do
        expect(Rollbar::Deploy).to receive(:report)
          .with(hash_including(
                  :rollbar_username => rollbar_user,
                  :local_username => rollbar_user,
                  :comment => rollbar_comment,
                  :status => :started,
                  :proxy => :ENV,
                  :dry_run => dry_run
                ),
                rollbar_token,
                rollbar_env,
                rollbar_revision).and_return(
                  :request_info => 'dummy request content',
                  :response_info => 'dummy response info',
                  :data => { :deploy_id => 1224 },
                  :success => true
                )

        expect(logger).to receive(:debug).with('dummy request content')
        expect(logger).to receive(:debug).with('dummy response info')

        subject.deploy_started(capistrano, logger, dry_run)

        expect(capistrano.fetch(:rollbar_deploy_id)).to eql(1224)
      end
    end

    context 'when an invalid response from the API is received' do
      it "prints the API request, response, doesn't set deploy_id and shows an error with the message from the API" do
        expect(::Rollbar::Deploy).to receive(:report)
          .and_return(
            :request_info => 'dummy request content',
            :response_info => 'dummy response info',
            :err => 1,
            :message => 'error message from the api',
            :success => false
          )

        expect(logger).to receive(:debug).with('dummy request content')
        expect(logger).to receive(:debug).with('dummy response info')
        expect(logger).to receive(:error).with(/Unable(.*)error message from the api/)

        expect(capistrano).to_not receive(:set).with(:rollbar_deploy_id, anything)

        subject.deploy_started(capistrano, logger, dry_run)
      end
    end

    context 'with --dry-run provided' do
      let(:dry_run) { true }

      it 'prints the API request, the skipping message and sets a dummy deploy_id' do
        expect(::Rollbar::Deploy).to receive(:report)
          .with(hash_including(:dry_run => dry_run), rollbar_token, rollbar_env, rollbar_revision)
          .and_return(:request_info => 'dummy request content')

        expect(logger).to receive(:debug).with('dummy request content')
        expect(logger).to receive(:info).with(/Skipping/)

        subject.deploy_started(capistrano, logger, dry_run)

        expect(capistrano.fetch(:rollbar_deploy_id)).to eql(123)
      end
    end
  end

  describe '.deploy_succeeded' do
    context 'with deploy_id' do
      let(:deploy_id) { '0987654321' }

      before do
        capistrano.set(:rollbar_deploy_id, deploy_id)
      end

      context 'when a valid response from the API is received' do
        it 'prints the API request, response and updates the appropriate deploy to succeeded' do
          expect(::Rollbar::Deploy).to receive(:update)
            .with(hash_including(
                    :proxy => :ENV,
                    :dry_run => dry_run
                  ),
                  rollbar_token,
                  deploy_id,
                  :succeeded).and_return(
                    :request_info => 'dummy request content',
                    :response_info => 'dummy response info',
                    :success => true
                  )

          expect(logger).to receive(:debug).with('dummy request content')
          expect(logger).to receive(:debug).with('dummy response info')
          expect(logger).to receive(:info).with(/Updated/)

          subject.deploy_succeeded(capistrano, logger, dry_run)
        end
      end

      context 'when an invalid response from the API is received' do
        it 'prints the API request, response and the error message from the API' do
          expect(::Rollbar::Deploy).to receive(:update)
            .with(hash_including(
                    :proxy => :ENV,
                    :dry_run => dry_run
                  ),
                  rollbar_token,
                  deploy_id,
                  :succeeded)
            .and_return(
              :request_info => 'dummy request content',
              :response_info => 'dummy response info',
              :success => false,
              :message => 'error message from the api'
            )

          expect(logger).to receive(:debug).with('dummy request content')
          expect(logger).to receive(:debug).with('dummy response info')
          expect(logger).to receive(:error).with(/Unable(.*)error message from the api/)

          subject.deploy_succeeded(capistrano, logger, dry_run)
        end
      end

      context 'with --dry-run provided' do
        let(:dry_run) { true }
        let(:deploy_id) { 123 }

        it 'calls deploy update with the dummy deploy_id, prints the API request and the skipping message' do
          expect(::Rollbar::Deploy).to receive(:update)
            .with(hash_including(
                    :dry_run => dry_run
                  ),
                  rollbar_token,
                  deploy_id,
                  :succeeded)
            .and_return(
              :request_info => 'dummy request content'
            )

          expect(logger).to receive(:debug).with('dummy request content')
          expect(logger).to receive(:info).with(/Skipping/)

          subject.deploy_succeeded(capistrano, logger, dry_run)
        end
      end
    end

    context 'without deploy_id' do
      before do
        capistrano.set(:rollbar_deploy_id, nil)
      end

      it 'displays an error message and exits' do
        expect(Rollbar::Deploy).to_not receive(:report)

        expect(logger).to receive(:error).with(/Failed(.*)No deploy id available/)

        subject.deploy_succeeded(capistrano, logger, dry_run)
      end
    end
  end

  describe '.deploy_failed' do
    context 'with deploy_id' do
      let(:deploy_id) { '0987654321' }

      before do
        capistrano.set(:rollbar_deploy_id, deploy_id)
      end

      context 'when a valid response from the API is received' do
        it 'prints the API request, response and updates the appropriate deploy to failed' do
          expect(::Rollbar::Deploy).to receive(:update)
            .with(hash_including(
                    :proxy => :ENV,
                    :dry_run => dry_run
                  ),
                  rollbar_token,
                  deploy_id,
                  :failed)
            .and_return(
              :request_info => 'dummy request content',
              :response_info => 'dummy response info',
              :success => true
            )

          expect(logger).to receive(:debug).with('dummy request content')
          expect(logger).to receive(:debug).with('dummy response info')
          expect(logger).to receive(:info).with(/Updated/)

          subject.deploy_failed(capistrano, logger, dry_run)
        end
      end

      context 'when an invalid response from the API is received' do
        it 'prints the API request, response and the error message from the API' do
          expect(::Rollbar::Deploy).to receive(:update)
            .with(hash_including(
                    :proxy => :ENV,
                    :dry_run => dry_run
                  ),
                  rollbar_token,
                  deploy_id,
                  :failed)
            .and_return(
              :request_info => 'dummy request content',
              :response_info => 'dummy response info',
              :success => false,
              :message => 'error message from the api'
            )

          expect(logger).to receive(:debug).with('dummy request content')
          expect(logger).to receive(:debug).with('dummy response info')
          expect(logger).to receive(:error).with(/Unable(.*)error message from the api/)

          subject.deploy_failed(capistrano, logger, dry_run)
        end
      end

      context 'with --dry-run provided' do
        let(:deploy_id) { 123 }
        let(:dry_run) { true }

        before do
          capistrano.set(:rollbar_deploy_id, deploy_id)
        end

        it 'calls deploy update with the dummy deploy_id, prints the API request and the skipping message' do
          expect(::Rollbar::Deploy).to receive(:update)
            .with(hash_including(
                    :dry_run => dry_run
                  ),
                  rollbar_token,
                  deploy_id,
                  :failed)
            .and_return(
              :request_info => 'dummy request content'
            )

          expect(logger).to receive(:debug).with('dummy request content')
          expect(logger).to receive(:info).with(/Skipping/)

          subject.deploy_failed(capistrano, logger, dry_run)
        end
      end
    end

    context 'without deploy_id' do
      before do
        capistrano.set(:rollbar_deploy_id, nil)
      end

      it 'displays an error message and exits' do
        expect(Rollbar::Deploy).to_not receive(:report)

        expect(logger).to receive(:error).with(/Failed(.*)No deploy id available/)

        subject.deploy_failed(capistrano, logger, dry_run)
      end
    end
  end
end
