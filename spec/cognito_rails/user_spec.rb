require 'spec_helper'

RSpec.describe CognitoRails::User, type: :model do
  include CognitoRails::Helpers

  let(:sample_cognito_email) { 'some@mail.com' }

  it 'validates email presence' do
    expect(subject).to have(1).error_on(:email)
    subject.email = sample_cognito_email
    expect(subject).to have(0).error_on(:email)
  end

  it 'finds an user by it' do
    expect(described_class).to receive(:cognito_client).and_return(fake_cognito_client)

    record = described_class.find(sample_cognito_id)
    expect(record).to be_a(described_class)
    expect(record.id).to eq(sample_cognito_id)
    expect(record.email).to eq(sample_cognito_email)
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
    include CognitoRails::Helpers

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
  end
end