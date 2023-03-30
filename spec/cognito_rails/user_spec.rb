# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe CognitoRails::User, type: :model do
  include CognitoRails::Helpers

  let(:sample_cognito_email) { 'some@mail.com' }
  let(:sample_cognito_phone) { '123456789' }

  it 'validates email presence' do
    expect(subject).to have(1).error_on(:email)
    subject.email = sample_cognito_email
    expect(subject).to have(0).error_on(:email)
  end

  it 'finds an user by id' do
    expect(described_class).to receive(:cognito_client).and_return(fake_cognito_client)

    record = described_class.find(sample_cognito_id)
    expect(record).to be_a(described_class)
    expect(record.id).to eq(sample_cognito_id)
    expect(record.email).to eq(sample_cognito_email)
    expect(record.user_class).to eq(User)
  end

  it 'finds a user with admin class' do
    expect(described_class).to receive(:cognito_client).and_return(fake_cognito_client)

    record = described_class.find(sample_cognito_id, Admin)
    expect(record.user_class).to eq(Admin)
  end

  it 'finds a user with default class' do
    expect(described_class).to receive(:cognito_client).and_return(fake_cognito_client)

    record = described_class.find(sample_cognito_id)
    expect(record.user_class).to eq(CognitoRails::Config.default_user_class.constantize)
  end

  context 'persistence' do
    it 'saves a new user' do
      expect_any_instance_of(described_class).to receive(:cognito_client).and_return(fake_cognito_client)
      subject.email = sample_cognito_email
      subject.save!
      expect(subject.id).to eq(sample_cognito_id)
    end

    it 'fails save on invalid record' do
      expect { subject.save! }.to raise_error ActiveRecord::RecordInvalid
    end
  end

  context 'deletion' do
    it 'deletes a new user' do
      allow_any_instance_of(described_class).to receive(:cognito_client).and_return(fake_cognito_client)
      subject.email = sample_cognito_email
      subject.save!

      subject.destroy!
    end

    it 'fails save on invalid record' do
      expect { subject.destroy! }.to raise_error ActiveRecord::RecordInvalid
    end
  end

  context 'user' do
    it 'creates a cognito user once created a new user' do
      expect_any_instance_of(CognitoRails::User).to receive(:cognito_client).and_return(fake_cognito_client)

      user = User.create!(email: sample_cognito_email)

      expect(user.external_id).to eq(sample_cognito_id)
    end

    it 'destroys the cognito user once destroyed the user' do
      expect(CognitoRails::User).to receive(:cognito_client).at_least(:once).and_return(fake_cognito_client)

      user = User.create!(email: sample_cognito_email)

      user.destroy!
    end

    it 'saves custom attributes in cognito' do
      expect(CognitoRails::User).to receive(:cognito_client).at_least(:once).and_return(fake_cognito_client)

      expect(fake_cognito_client).to receive(:admin_create_user).with(
        hash_including(
          user_attributes: array_including(
            [
              {
                name: 'email_verified', value: 'True'
              },
              {
                name: 'email', value: sample_cognito_email
              },
              {
                name: 'custom:role', value: 'user'
              },
              {
                name: 'custom:name', value: 'TestName'
              }
            ]
          )
        )
      )

      User.create!(email: sample_cognito_email, name: 'TestName')
    end
  end

  context 'class methods' do
    before do
      expect(CognitoRails::User).to receive(:cognito_client).at_least(:once).and_return(fake_cognito_client)
    end

    it '#sync_from_cognito!' do
      expect(fake_cognito_client).to receive(:list_users).and_return(
        OpenStruct.new(
          users: [
            build_cognito_user_data('some@example.com'),
            build_cognito_user_data('some2@example.com')
          ],
          pagination_token: nil
        )
      )

      expect do
        users = User.sync_from_cognito!

        expect(users).to be_a(Array)
        expect(users.size).to eq(2)
        expect(users.first).to be_a(User)
      end.to change { User.count }.by(2)

      expect(User.pluck(:email)).to match_array(['some@example.com', 'some2@example.com'])
      expect(User.pluck(:name)).to match_array(['Giovanni', 'Giovanni'])
    end

    it '#sync_to_cognito!' do
      User.create!(email: sample_cognito_email)

      expect_any_instance_of(User).to receive(:init_cognito_user).exactly(1).times
      User.sync_to_cognito!
    end
  end

  context 'admin' do
    before do
      expect(CognitoRails::User).to receive(:cognito_client).at_least(:once).and_return(fake_cognito_client)
    end

    it '#find_by_cognito' do
      admin = Admin.create!(email: sample_cognito_email, phone: '12345678')

      expect(Admin.find_by_cognito(sample_cognito_id)).to eq(admin)
    end

    it 'creates a cognito user once created a new admin' do
      admin = Admin.create!(email: sample_cognito_email, phone: '12345678')

      expect(admin.cognito_external_id).to eq(sample_cognito_id)
    end

    it 'destroys the cognito user once destroyed the admin' do
      admin = Admin.create!(email: sample_cognito_email, phone: '12345678')

      admin.destroy!
    end

    it 'saves custom attributes in cognito' do
      expect(fake_cognito_client).to receive(:admin_create_user).with(
        hash_including(
          user_attributes: array_including(
            [
              {
                name: 'phone_number_verified', value: 'True'
              },
              {
                name: 'email_verified', value: 'True'
              },
              {
                name: 'phone_number', value: '12345678'
              },
              {
                name: 'email', value: sample_cognito_email
              },
              {
                name: 'custom:role', value: 'admin'
              }
            ]
          )
        )
      )

      Admin.create!(email: sample_cognito_email, phone: '12345678')
    end
  end
end
