require 'spec_helper'

RSpec.describe CognitoRails::Controller, type: :model do
  include CognitoRails::Helpers

  context 'with an updated API controller' do
    class ReadTokenFromParamsController < ActionController::API
      cognito_authentication
      cognito_token_from param: :token_in_param

      def request
        @request ||= OpenStruct.new(
          {
            headers: { 'Authorization' => 'token_in_headers' },
            query_parameters: {
              token_in_param: 'token_in_params',
              do_not_check: 'there is something here but not declared on class'
            }
          }
        )
      end
    end

    let(:controller) { ReadTokenFromParamsController.new }
    let(:param_token) { 'token_in_params' }
    let(:header_token) { 'header_token' }

    it 'returns no user if the bearer from the param is invalid' do
      expect(CognitoRails::JWT).not_to receive(:decode).with(header_token)
      expect(CognitoRails::JWT).to receive(:decode).with(param_token).at_least(:once).and_return([{ 'sub' => '111111111' }])
      expect(controller.current_user).to eq(nil)
    end

    it 'returns a user if the token in param is correct' do
      user = User.create!(email: sample_cognito_email, external_id: '111111111')

      expect(CognitoRails::JWT).not_to(
        receive(:decode)
        .with(header_token)
      )
      expect(CognitoRails::JWT).to(
        receive(:decode)
        .with(param_token)
        .at_least(:once)
        .and_return([{ 'sub' => user.external_id }])
      )
      expect(controller.current_user).to eq(user)
    end
  end

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
