require 'spec_helper'

RSpec.describe CognitoRails::Controller, type: :model do
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

  context 'with a custom controller attribute' do
    class AdminController < ActionController::Base
      cognito_authentication user_class: 'Admin', attribute_name: :admin_user

      def request
        @request ||= OpenStruct.new({ headers: { 'Authorization' => 'Bearer aaaaa' } })
      end
    end

    let(:controller) { AdminController.new }

    it 'returns a user through the configured attribute' do
      user = Admin.create!(email: sample_cognito_email, phone: sample_cognito_phone, cognito_id: '123123123')

      expect(CognitoRails::JWT).to receive(:decode).at_least(:once).and_return([{ 'sub' => '123123123' }])
      expect(controller.admin_user).to eq(user)
    end

    it 'keeps current_user retrocompatible with the default class' do
      user = User.create!(email: sample_cognito_email, external_id: '123123123')

      expect(CognitoRails::JWT).to receive(:decode).at_least(:once).and_return([{ 'sub' => '123123123' }])
      expect(controller.current_user).to eq(user)
    end
  end

  context 'with multiple cognito_authentication declarations' do
    class DualAuthController < ActionController::Base
      cognito_authentication
      cognito_authentication user_class: 'Admin', attribute_name: :admin_user

      def request
        @request ||= OpenStruct.new({ headers: { 'Authorization' => 'Bearer aaaaa' } })
      end
    end

    let(:controller) { DualAuthController.new }

    it 'resolves both configured user readers' do
      user = User.create!(email: sample_cognito_email, external_id: '123123123')
      admin = Admin.create!(email: sample_cognito_email, phone: sample_cognito_phone, cognito_id: '123123123')

      expect(CognitoRails::JWT).to receive(:decode).at_least(:once).and_return([{ 'sub' => '123123123' }])
      expect(controller.current_user).to eq(user)
      expect(controller.admin_user).to eq(admin)
    end
  end
end
