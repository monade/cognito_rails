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
    # @option attributes [String,Symbol,Class, nil] :user_class
    def initialize(attributes = {})
      attributes = attributes.with_indifferent_access
      self.email = attributes[:email]
      self.password = attributes[:password] || Config.password_generator.call
      self.phone = attributes[:phone]
      self.user_class = self.class.resolve_user_class(attributes[:user_class]) || Config.default_user_class.constantize
      self.custom_attributes = attributes[:custom_attributes]
    end

    def self.find_raw(id, user_class = nil)
      cognito_client_for(user_class).admin_get_user(
        {
          user_pool_id: user_pool_id_for(user_class), # required
          username: id # required
        }
      )
    end

    # @param id [String]
    # @param user_class [nil,Object]
    # @return [CognitoRails::User]
    def self.find(id, user_class = nil)
      result = find_raw(id, user_class)
      user = new(user_class: user_class)
      user.id = result.username
      user.email = extract_cognito_attribute(result.user_attributes, :email)
      user.phone = extract_cognito_attribute(result.user_attributes, :phone_number)
      user
    end

    def self.all(user_class = nil)
      cognito_client_for(user_class).list_users(user_pool_id: user_pool_id_for(user_class))
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
          user_pool_id: user_pool_id,
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

    # @return [String]s
    def self.user_pool_id_for(user_class)
      user_class = resolve_user_class(user_class)
      user_class&._cognito_aws_user_pool_id || CognitoRails::Config.aws_user_pool_id
    end

    # @return [Aws::CognitoIdentityProvider::Client]
    # @raise [RuntimeError]
    def self.cognito_client
      cognito_client_for_credentials(CognitoRails::Config.aws_client_credentials)
    end

    def self.cognito_client_for(user_class)
      user_class = resolve_user_class(user_class)
      model_credentials = user_class&._cognito_aws_client_credentials
      return cognito_client if model_credentials.nil?

      cognito_client_for_credentials(model_credentials)
    end

    def self.cognito_region_for(user_class = nil)
      user_class = resolve_user_class(user_class)
      credentials = user_class&._cognito_aws_client_credentials
      credentials = CognitoRails::Config.aws_client_credentials if credentials.nil?

      credentials.with_indifferent_access[:region] || CognitoRails::Config.aws_region
    end

    def self.cognito_client_for_credentials(credentials)
      client_options = cognito_client_options(credentials)
      cache_key = client_options.sort_by { |key, _| key.to_s }
      @cognito_clients ||= {}
      @cognito_clients[cache_key] ||= Aws::CognitoIdentityProvider::Client.new(client_options)
    end

    def self.extract_cognito_attribute(attributes, column)
      attributes.find { |attribute| attribute[:name] == column.to_s }&.dig(:value)
    end

    def self.cognito_client_options(credentials)
      credentials = credentials.with_indifferent_access
      region = credentials.delete(:region) || CognitoRails::Config.aws_region

      { region: region }.merge(credentials).with_indifferent_access
    end

    # @param user_class [String,Symbol,Class,nil]
    # @return [Class,nil]
    def self.resolve_user_class(user_class)
      case user_class
      when nil
        nil
      when String, Symbol
        user_class.to_s.constantize
      else
        user_class
      end
    end

    private

    def user_pool_id
      self.class.user_pool_id_for(user_class)
    end

    # @return [Aws::CognitoIdentityProvider::Client]
    def cognito_client
      self.class.cognito_client_for(user_class)
    end

    # @return [Boolean]
    def verify_email?
      user_class._cognito_verify_email
    end

    # @return [Boolean]
    def verify_phone?
      user_class._cognito_verify_phone
    end

    # @return [Symbol] :temporary | :user_provided
    def cognito_password_policy
      user_class._cognito_password_policy || :temporary
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

    # @return [Array<Hash>]
    def password_attributes
      if cognito_password_policy == :user_provided
        { message_action: 'SUPPRESS' }
      else
        { temporary_password: password }
      end
    end

    def set_user_provided_password
      cognito_client.admin_set_user_password(
        {
          user_pool_id: user_pool_id,
          username: email,
          password: password,
          permanent: true
        }
      )
    end

    def save_for_create
      resp = cognito_client.admin_create_user(
        {
          user_pool_id: user_pool_id,
          username: email,
          user_attributes: [
            *general_user_attributes,
            *verify_user_attributes
          ],
          **password_attributes
        }
      )

      set_user_provided_password if cognito_password_policy == :user_provided

      self.id = resp.user.attributes.find { |a| a[:name] == 'sub' }[:value]
    end

    def save_for_update
      cognito_client.admin_update_user_attributes(
        {
          user_pool_id: user_pool_id,
          username: id,
          user_attributes: [
            *general_user_attributes
          ]
        }
      )
    end
  end
end
