# frozen_string_literal: true

require 'active_record'
require 'active_model/validations'
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
  class User
    SCOPE_KEYS = %i[
      user_pool_id
      aws_region
      access_key_id
      secret_access_key
    ].freeze

    include ActiveModel::Validations

    attr_accessor :id, :email, :password, :phone, :custom_attributes, :user_class

    validates :email, presence: true

    # Helper bound to a specific Cognito configuration.
    class CredentialsScope
      def initialize(scope = {})
        @scope = User.scope_from(scope)
      end

      # @param id [String]
      # @return [OpenStruct]
      def find_raw(id)
        cognito_client.admin_get_user(user_pool_id: user_pool_id, username: id)
      end

      # @param id [String]
      # @return [CognitoRails::User]
      def find(id)
        response = find_raw(id)

        new.tap do |user|
          user.id = response.username
          user.email = User.extract_cognito_attribute(response.user_attributes, :email)
          user.phone = User.extract_cognito_attribute(response.user_attributes, :phone_number)
        end
      end

      # @return [OpenStruct]
      def all
        cognito_client.list_users(user_pool_id: user_pool_id)
      end

      # @param attributes [Hash]
      # @return [CognitoRails::User]
      def create!(attributes = {})
        user = new(attributes)
        user.save!
        user
      end

      # @param attributes [Hash]
      # @return [CognitoRails::User]
      def create(attributes = {})
        user = new(attributes)
        user.save
        user
      end

      # @param attributes [Hash]
      # @return [CognitoRails::User]
      def new(attributes = {})
        attrs = attributes.with_indifferent_access
        User.new(attrs.merge(scope: @scope))
      end

      # @return [String]
      def user_pool_id
        @scope[:user_pool_id] || Config.aws_user_pool_id
      end

      # @return [String]
      def aws_region
        @scope[:aws_region] || config_credentials[:region] || Config.aws_region
      end

      # @return [Aws::CognitoIdentityProvider::Client]
      def cognito_client
        return User.cognito_client if use_default_client?

        credentials = {
          access_key_id: @scope[:access_key_id],
          secret_access_key: @scope[:secret_access_key]
        }.compact

        User.cognito_client_for_credentials(credentials, aws_region: aws_region)
      end

      private

      def use_default_client?
        @scope[:aws_region].nil? && @scope[:access_key_id].nil? && @scope[:secret_access_key].nil?
      end

      def config_credentials
        Config.aws_client_credentials.with_indifferent_access
      end
    end

    # @param attributes [Hash]
    # @option attributes [String] :email
    # @option attributes [String, nil] :password
    # @option attributes [String, nil] :phone
    # @option attributes [Array<Hash>, nil] :custom_attributes
    # @option attributes [String, nil] :user_pool_id
    # @option attributes [String, nil] :aws_region
    # @option attributes [String, nil] :access_key_id
    # @option attributes [String, nil] :secret_access_key
    # @option attributes [Boolean, nil] :verify_email
    # @option attributes [Boolean, nil] :verify_phone
    # @option attributes [Symbol, nil] :password_policy
    # @option attributes [String,Symbol,Class,nil] :user_class
    def initialize(attributes = {})
      attributes = attributes.with_indifferent_access

      @scope = self.class.extract_scope(attributes)
      @verify_email = attributes[:verify_email]
      @verify_phone = attributes[:verify_phone]
      @password_policy = attributes[:password_policy]

      self.user_class = resolve_instance_user_class(attributes)
      self.email = attributes[:email]
      self.password = attributes[:password] || Config.password_generator.call
      self.phone = attributes[:phone]
      self.custom_attributes = attributes[:custom_attributes]
    end

    # @param credentials [Hash]
    # @return [CredentialsScope]
    def self.with_credentials(credentials = {})
      CredentialsScope.new(credentials)
    end

    # @param id [String]
    # @return [OpenStruct]
    def self.find_raw(id)
      resolve_scope(nil).find_raw(id)
    end

    # @param id [String]
    # @return [CognitoRails::User]
    def self.find(id)
      resolve_scope(nil).find(id)
    end

    # @return [OpenStruct]
    def self.all
      resolve_scope(nil).all
    end

    # @param attributes [Hash]
    # @return [CognitoRails::User]
    def self.create!(attributes = {})
      user = new(attributes)
      user.save!
      user
    end

    # @param attributes [Hash]
    # @return [CognitoRails::User]
    def self.create(attributes = {})
      user = new(attributes)
      user.save
      user
    end

    # @return [Aws::CognitoIdentityProvider::Client]
    def self.cognito_client
      cognito_client_for_credentials(Config.aws_client_credentials)
    end

    # @param credentials [Hash]
    # @param aws_region [String,nil]
    # @return [Aws::CognitoIdentityProvider::Client]
    def self.cognito_client_for_credentials(credentials, aws_region: nil)
      client_options = cognito_client_options(credentials, aws_region: aws_region)
      cache_key = client_options.sort_by { |key, _| key.to_s }

      @cognito_clients ||= {}
      @cognito_clients[cache_key] ||= Aws::CognitoIdentityProvider::Client.new(client_options)
    end

    # @param attributes [Array<Hash,OpenStruct>]
    # @param column [String,Symbol]
    # @return [String,nil]
    def self.extract_cognito_attribute(attributes, column)
      attribute = attributes.find { |entry| read_attribute_name(entry) == column.to_s }
      return unless attribute

      read_attribute_value(attribute)
    end

    # @param credentials [Hash]
    # @param aws_region [String,nil]
    # @return [Hash]
    def self.cognito_client_options(credentials, aws_region: nil)
      credentials = (credentials || {}).with_indifferent_access
      region = aws_region || credentials[:region] || Config.aws_region

      {
        region: region,
        access_key_id: credentials[:access_key_id],
        secret_access_key: credentials[:secret_access_key]
      }.compact.with_indifferent_access
    end

    def self.scope_from(scope)
      case scope
      when nil
        {}.with_indifferent_access
      when Hash
        normalize_scope_hash(scope)
      when Class
        CognitoRails::Config.user_scope_for(scope)
      else
        raise ArgumentError, 'scope must be a Hash'
      end
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

    private

    def self.resolve_scope(scope = nil)
      with_credentials(scope_from(scope))
    end

    def self.extract_scope(attributes)
      inline_scope = attributes.slice(*SCOPE_KEYS).with_indifferent_access
      raw_scope = attributes.delete(:scope)
      raw_scope = raw_scope.nil? ? {} : raw_scope

      merged_scope = raw_scope.with_indifferent_access.merge(inline_scope)

      scope_from(merged_scope)
    end

    def self.normalize_scope_hash(scope)
      scope = scope.with_indifferent_access

      {
        user_pool_id: scope[:user_pool_id],
        aws_region: scope[:aws_region],
        access_key_id: scope[:access_key_id],
        secret_access_key: scope[:secret_access_key]
      }.compact.with_indifferent_access
    end

    def self.read_attribute_name(attribute)
      attribute.respond_to?(:name) ? attribute.name.to_s : attribute[:name].to_s
    end

    def self.read_attribute_value(attribute)
      attribute.respond_to?(:value) ? attribute.value : attribute[:value]
    end

    def resolve_instance_user_class(attributes)
      resolved = CognitoRails::Utils.resolve_model_class(attributes[:user_class])
      resolved || Config.default_user_class.constantize
    end

    def user_pool_id
      credentials_scope.user_pool_id
    end

    def aws_region
      credentials_scope.aws_region
    end

    # @return [Aws::CognitoIdentityProvider::Client]
    def cognito_client
      credentials_scope.cognito_client
    end

    # @return [Boolean]
    def verify_email?
      return @verify_email unless @verify_email.nil?

      user_class._cognito_verify_email
    end

    # @return [Boolean]
    def verify_phone?
      return @verify_phone unless @verify_phone.nil?

      user_class._cognito_verify_phone
    end

    # @return [Symbol] :temporary | :user_provided
    def cognito_password_policy
      @password_policy || user_class._cognito_password_policy || :temporary
    end

    # @return [Array<Hash>]
    def general_user_attributes
      [
        *([{ name: 'email', value: email }] if email),
        *([{ name: 'phone_number', value: phone }] if phone),
        *Array(custom_attributes)
      ]
    end

    # @return [Array<Hash>]
    def verify_user_attributes
      [
        *([{ name: 'email_verified', value: 'True' }] if verify_email?),
        *([{ name: 'phone_number_verified', value: 'True' }] if verify_phone?)
      ]
    end

    # @return [Hash]
    def password_attributes
      if cognito_password_policy == :user_provided
        { message_action: 'SUPPRESS' }
      else
        { temporary_password: password }
      end
    end

    def set_user_provided_password
      cognito_client.admin_set_user_password(
        user_pool_id: user_pool_id,
        username: email,
        password: password,
        permanent: true
      )
    end

    def save_for_create
      response = cognito_client.admin_create_user(
        {
          user_pool_id: user_pool_id,
          username: email,
          user_attributes: [*general_user_attributes, *verify_user_attributes],
          **password_attributes
        }
      )

      set_user_provided_password if cognito_password_policy == :user_provided
      self.id = self.class.extract_cognito_attribute(response.user.attributes, :sub)
    end

    def save_for_update
      cognito_client.admin_update_user_attributes(
        user_pool_id: user_pool_id,
        username: id,
        user_attributes: [*general_user_attributes]
      )
    end

    def credentials_scope
      @credentials_scope ||= self.class.with_credentials(@scope)
    end
  end
end
