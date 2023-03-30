module CognitoRails::Helpers
  extend ActiveSupport::Concern

  included do
    let(:sample_cognito_id) { SecureRandom.uuid }
    let(:sample_cognito_email) { 'some@mail.com' }
    let(:sample_cognito_phone) { '123456789' }
    let(:fake_cognito_client) do
      client = double
      allow(client).to receive(:admin_create_user) do |params|
        expect(params).to match_structure(
          user_pool_id: one_of(String, nil),
          username: String,
          temporary_password: String,
          user_attributes: a_list_of(name: String, value: one_of(String, nil))
        )
        OpenStruct.new(user: OpenStruct.new(attributes: [{ name: 'sub', value: sample_cognito_id }]))
      end

      allow(client).to receive(:admin_delete_user) do |params|
        expect(params).to match_structure(
          user_pool_id: one_of(String, nil),
          username: String
        )
        OpenStruct.new
      end
      allow(client).to receive(:admin_get_user).and_return(
        OpenStruct.new(
          {
            username: sample_cognito_id,
            user_attributes: [
              { name: 'sub', value: sample_cognito_id },
              { name: 'email', value: sample_cognito_email },
              { name: 'phone', value: sample_cognito_phone },
              { name: 'custom:name', value: "TestName" }
            ]
          }
        )
      )
      client
    end
  end

  def build_cognito_user_data(email)
    OpenStruct.new(
      username: SecureRandom.uuid,
      user_status: 'CONFIRMED',
      enabled: true,
      user_last_modified_date: Time.now,
      attributes: [
        OpenStruct.new(
          name: 'email',
          value: email
        ),
        OpenStruct.new(
          name: 'custom:name',
          value: 'Giovanni'
        )
      ],
      mfa_options: []
    )
  end
end
