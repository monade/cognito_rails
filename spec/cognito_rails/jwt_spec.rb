# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe CognitoRails::JWT, type: :model do
  # rubocop:enable Metrics/BlockLength
  before do
    allow(URI).to receive(:open).and_return(double(read: jwks))
  end

  context 'with an invalid jwtk' do
    let(:jwks) { '{}' }

    it 'decode returns nil' do
      expect(described_class.decode('aaaa')).to be_nil
    end
  end

  context 'with a valid jwtk' do
    let(:jwk) { JWT::JWK.new(OpenSSL::PKey::RSA.new(2048), 'optional-kid') }
    let(:jwks) { { keys: [jwk.export] }.to_json }
    let(:payload) { { 'data' => 'data' } }
    let(:token) do
      headers = { kid: jwk.kid }

      JWT.encode(payload, jwk.keypair, 'RS256', headers)
    end

    it 'decodes a token correctly' do
      expect(described_class.decode(token)[0]).to eq({
                                                       'data' => 'data'
                                                     })
    end

    it 'fails to decode if the token is invalid' do
      expect(described_class.decode('aaaa')).to be_nil
    end
  end
end
