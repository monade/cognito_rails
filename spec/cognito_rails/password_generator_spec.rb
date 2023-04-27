# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CognitoRails::PasswordGenerator do
  it 'generates a password' do
    expect(described_class.generate).to be_a(String)
  end

  it 'generates a password with the correct length' do
    1000.times do
      expect(described_class.generate(8..8).length).to eq(8)
    end
  end

  it 'contains at least one letter, one number, one upper case letter, one symbol' do
    1000.times do
      password = described_class.generate
      expect(password).to match(/[a-z]/)
      expect(password).to match(/[A-Z]/)
      expect(password).to match(/[0-9]/)
      include_symbol = CognitoRails::PasswordGenerator::SPECIAL.any? do |symbol|
        password.include?(symbol)
      end
      expect(include_symbol).to be_truthy
    end
  end
end
