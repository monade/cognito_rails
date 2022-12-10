require 'spec_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe CognitoRails::Controller, type: :model do
  # rubocop:enable Metrics/BlockLength
  include CognitoRails::Helpers

  context 'with an API controller' do
    class MyApiController < ActionController::API
      cognito_authentication

      def request
        @request ||= OpenStruct.new({ headers: { 'Authorization' => 'Bearer aaaaa' } })
      end
    end
    let(:controller) { MyApiController.new }

    it 'returns no user if the bearer is invalid' do
      expect(CognitoRails::JWT).to receive(:decode).at_least(:once).and_return([{ 'sub' => '123123123' }])
      expect(controller.current_user).to eq(nil)
    end

    it 'returns a user if the token is correct' do
      user = User.create!(email: sample_cognito_email, external_id: '123123123')

      expect(CognitoRails::JWT).to receive(:decode).at_least(:once).and_return([{ 'sub' => '123123123' }])
      expect(controller.current_user).to eq(user)
    end
  end

  context 'with a standard controller' do
    class MyController < ActionController::Base
      cognito_authentication user_class: 'Admin'

      def request
        @request ||= OpenStruct.new({ headers: { 'Authorization' => 'Bearer aaaaa' } })
      end
    end
    let(:controller) { MyController.new }

    it 'returns no user if the bearer is invalid' do
      expect(CognitoRails::JWT).to receive(:decode).at_least(:once).and_return([{ 'sub' => '123123123' }])
      expect(controller.current_user).to eq(nil)
    end

    it 'returns a user if the token is correct' do
      user = Admin.create!(email: sample_cognito_email, phone: sample_cognito_phone, cognito_id: '123123123')

      expect(CognitoRails::JWT).to receive(:decode).at_least(:once).and_return([{ 'sub' => '123123123' }])
      expect(controller.current_user).to eq(user)
    end
  end
end
