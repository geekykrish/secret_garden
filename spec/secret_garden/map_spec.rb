require 'spec_helper'

require 'fileutils'
require 'tmpdir'

require 'secret_garden/map'

describe SecretGarden::Map do
  let(:pwd) { Dir.mktmpdir }
  let(:map) { described_class.new root: pwd }

  around do |example|
    ENV['VAULT_ENV'] = 'myenv'
    example.call
    ENV.delete 'VAULT_ENV'
  end

  after { FileUtils.remove_entry pwd }

  describe '#entries' do

    it 'loads entries from <root>/Secretfile' do
      File.open File.join(pwd, 'Secretfile'), 'w' do |f|
        f.puts <<-SECRETS
# This is my Secretfile
FOO      path/to/foo
BAR_COOL path/to/bar:rab
BAZ      overwrite
BAZ      path/to/$VAULT_ENV/baz:zab
        SECRETS
      end

      expect(map.entries['FOO']).to be_a(SecretGarden::Secret)
      expect(map.entries['BAR_COOL']).to be_a(SecretGarden::Secret)
      expect(map.entries['BAZ']).to be_a(SecretGarden::Secret)
    end

  end

  describe '#parse_secret' do

    subject { map.parse_secret line }

    context 'secret is bare' do
      let(:line) { 'SECRET    path/to/me' }

      it { is_expected.to eq ['SECRET', 'path/to/me', nil] }
    end

    context 'secret has a property in its path' do
      let(:line) { 'SECRET    path/to/me:item' }

      it { is_expected.to eq ['SECRET', 'path/to/me', 'item'] }
    end

    context 'secret has an environment variable in its path' do
      let(:line) { 'SECRET    path/to/$VAULT_ENV/me:item' }

      it { is_expected.to eq ['SECRET', 'path/to/myenv/me', 'item'] }
    end

    context 'secret has a bracketed environment variable in its path' do
      let(:line) { 'SECRET    path/to/${VAULT_ENV}/me:item' }

      it { is_expected.to eq ['SECRET', 'path/to/myenv/me', 'item'] }
    end

    context 'secret has undefined environment variable in its path' do
      let(:line) { 'SECRET    path/to/${OMGNOTDEFINED}/me:item' }

      it { is_expected.to eq ['SECRET', 'path/to//me', 'item'] }
      
      it 'warns' do
        expect(STDERR).to receive(:puts)
        subject
      end
    end

  end

end

