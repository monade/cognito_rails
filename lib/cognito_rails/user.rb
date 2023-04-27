# frozen_string_literal: true

require 'active_record'
require 'active_model/validations'
require 'securerandom'
require 'aws-sdk-cognitoidentityprovider'

module CognitoRails
  # A class to map the cognito user to a model-like object
  #
  # @!attribute id [rw]
  #   @return [String]
  # @!attribute email [rw]
  #   @return [String]
  # @!attribute password [rw]
  #   @return [String,nil]
  # @!attribute phone [rw]
  #   @return [String,nil]
  # @!attribute custom_attributes [rw]
  #   @return [Array<Hash>,nil]
  # @!attribute user_class [rw]
  #   @return [Class,nil]
  # rubocop:disable Metrics/ClassLength
  class User
    # rubocop:enable Metrics/ClassLength

    include ActiveModel::Validations

    attr_accessor :id, :email, :password, :phone, :custom_attributes, :user_class

    validates :email, presence: true

    # @param attributes [Hash]
    # @option attributes [String] :email
    # @option attributes [String, nil] :password
    # @option attributes [String, nil] :phone
    # @option attributes [Array<Hash>, nil] :custom_attributes
    # @option attributes [Class, nil] :user_class
    def initialize(attributes = {})
      attributes = attributes.with_indifferent_access
      self.email = attributes[:email]
      self.password = attributes[:password] || Config.password_generator.call
      self.phone = attributes[:phone]
      self.user_class = attributes[:user_class] || Config.default_user_class.constantize
      self.custom_attributes = attributes[:custom_attributes]
    end

    # @param id [String]
    # @param user_class [nil,Object]
    # @return [CognitoRails::User]
    def self.find(id, user_class = nil)
      result = cognito_client.admin_get_user(
        {
          user_pool_id: CognitoRails::Config.aws_user_pool_id, # required
          username: id # required
        }
      )
      user = new(user_class: user_class)
      user.id = result.username
      user.email = extract_cognito_attribute(result.user_attributes, :email)
      user.phone = extract_cognito_attribute(result.user_attributes, :phone_number)
      user
    end

    def self.all
      cognito_client.list_users(user_pool_id: CognitoRails::Config.aws_user_pool_id)
    end

    # @param attributes [Hash]
    # @option attributes [String] :email
    # @option attributes [String] :password
    # @option attributes [String, nil] :phone
    # @option attributes [Array<Hash>, nil] :custom_attributes
    # @option attributes [Class, nil] :user_class
    # @return [CognitoRails::User]
    def self.create!(attributes = {})
      user = new(attributes)
      user.save!
      user
    end

    # @param attributes [Hash]
    # @option attributes [String] :email
    # @option attributes [String] :password
    # @option attributes [String, nil] :phone
    # @option attributes [Array<Hash>, nil] :custom_attributes
    # @option attributes [Class, nil] :user_class
    # @return [CognitoRails::User]
    def self.create(attributes = {})
      user = new(attributes)
      user.save
      user
    end

    # @return [Boolean]
    def new_record?
      !persisted?
    end

    # @return [Boolean]
    def persisted?
      id.present?
    end

    # @return [Boolean]
    # @raise [ActiveRecord::RecordInvalid]
    def save!
      save || (raise ActiveRecord::RecordInvalid, self)
    end

    # @return [Boolean]
    def save
      return false unless validate

      if persisted?
        save_for_update
      else
        save_for_create
      end

      true
    end

    # @return [Boolean]
    def destroy
      return false if new_record?

      cognito_client.admin_delete_user(
        {
          user_pool_id: CognitoRails::Config.aws_user_pool_id,
          username: id
        }
      )
      self.id = nil

      true
    end

    # @return [Boolean]
    # @raise [ActiveRecord::RecordInvalid]
    def destroy!
      destroy || (raise ActiveRecord::RecordInvalid, self)
    end

    # @return [Aws::CognitoIdentityProvider::Client]
    # @raise [RuntimeError]
    def self.cognito_client
      @cognito_client ||= Aws::CognitoIdentityProvider::Client.new(
        { region: CognitoRails::Config.aws_region }.merge(CognitoRails::Config.aws_client_credentials)
      )
    end

    def self.extract_cognito_attribute(attributes, column)
      attributes.find { |attribute| attribute[:name] == column.to_s }&.dig(:value)
    end

    private

    # @return [Aws::CognitoIdentityProvider::Client]
    def cognito_client
      self.class.cognito_client
    end

    # @return [Boolean]
    def verify_email?
      user_class._cognito_verify_email
    end

    # @return [Boolean]
    def verify_phone?
      user_class._cognito_verify_phone
    end

    # @return [Array<Hash>]
    def general_user_attributes
      [
        *([{ name: 'email', value: email }] if email),
        *([{ name: 'phone_number', value: phone }] if phone),
        *custom_attributes
      ]
    end

    # @return [Array<Hash>]
    def verify_user_attributes
      [
        *([{ name: 'email_verified', value: 'True' }] if verify_email?),
        *([{ name: 'phone_number_verified', value: 'True' }] if verify_phone?)
      ]
    end

    def save_for_create
      resp = cognito_client.admin_create_user(
        {
          user_pool_id: CognitoRails::Config.aws_user_pool_id,
          username: email,
          temporary_password: password,
          user_attributes: [
            *general_user_attributes,
            *verify_user_attributes
          ]
        }
      )
      self.id = resp.user.attributes.find { |a| a[:name] == 'sub' }[:value]
    end

    def save_for_update
      cognito_client.admin_update_user_attributes(
        {
          user_pool_id: CognitoRails::Config.aws_user_pool_id,
          username: id,
          user_attributes: [
            *general_user_attributes
          ]
        }
      )
    end
  end
end
