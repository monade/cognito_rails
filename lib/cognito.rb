require 'active_support/concern'

# cognito_concern.rb
module CognitoConcern
  extend ActiveSupport::Concern

  def current_user
    @current_user ||= User.find_by(external_id: request.headers['x-auth-id']) if request.headers['x-auth-id']
  end
end

# cognito_user.rb
class CognitoUser
  include ActiveModel::Validations

  attr_accessor :id, :email, :password

  validates :email, presence: true

  def initialize(attributes = {})
    attributes = attributes.with_indifferent_access
    self.email = attributes[:email]
    self.password = SecureRandom.urlsafe_base64 || attributes[:password]
  end

  def user
    @user ||= User.find_by(external_id: id)
  end

  def self.find(id)
    result = cognito_client.admin_get_user(
      {
        user_pool_id: credentials[:user_pool_id], # required
        username: id # required
      }
    )
    user = new
    user.id = result.username
    user.email = result.user_attributes.find { |attribute| attribute[:name] == 'email' }[:value]
    user
  end

  def self.create!(attributes = {})
    user = new(attributes)
    user.save!
    user
  end

  def self.create
    user = new(attributes)
    user.save
    user
  end

  def new_record?
    !persisted?
  end

  def persisted?
    id.present?
  end

  def save!
    save || (raise ActiveRecord::RecordInvalid, self)
  end

  def save
    return false unless validate
    raise 'update feature not implemented!' if persisted?

    resp = cognito_client.admin_create_user(
      {
        user_pool_id: credentials[:user_pool_id], # required
        username: email, # required
        temporary_password: password, # required
        user_attributes: [
          {
            name: 'email',
            value: email
          },
          {
            name: 'email_verified',
            value: 'True'
          }
        ],
        desired_delivery_mediums: ['EMAIL']
      }
    )
    self.id = resp.user.attributes.find { |a| a[:name] == 'sub' }[:value]
    true
  end

  def destroy
    return false if new_record?

    cognito_client.admin_delete_user(
      {
        user_pool_id: credentials[:user_pool_id],
        username: id
      }
    )
    self.id = nil

    true
  end

  def destroy!
    destroy || (raise ActiveRecord::RecordInvalid, self)
  end

  private

  def cognito_client
    self.class.cognito_client
  end

  def self.cognito_client
    raise 'Can\'t create user in test mode' if Rails.env.test?

    @cognito_client ||= Aws::CognitoIdentityProvider::Client.new(
      access_key_id: credentials[:access_key_id],
      secret_access_key: credentials[:secret_access_key],
      region: credentials[:region]
    )
  end

  def credentials
    self.class.credentials
  end

  def self.credentials
    Rails.application.credentials[:cognito] || {}
  end
end

module Cognito
  extend ActiveSupport::Concern
  
  def cognito_user
    @cognito_user ||= CognitoUser.find(external_id)
  end

  def init_cognito_user
    return if external_id.present?

    cognito_user = CognitoUser.new(email:)
    cognito_user.save!
    self.external_id = cognito_user.id
  end

  def destroy_cognito_user
    cognito_user&.destroy!
  end

  module Initializer
    def as_cognito_user
			send :include, Cognito
		end
	end
end
ActiveRecord::Base.send :extend, Cognito::Initializer