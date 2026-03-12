# frozen_string_literal: true

require 'active_record'

module CognitoRails
  # ActiveRecord model extension
  module Model
    extend ActiveSupport::Concern

    included do
      class_attribute :_cognito_verify_email
      class_attribute :_cognito_verify_phone
      class_attribute :_cognito_custom_attributes
      class_attribute :_cognito_attribute_name
      class_attribute :_cognito_password_policy
      class_attribute :_cognito_aws_user_pool_id
      class_attribute :_cognito_aws_client_credentials
      self._cognito_custom_attributes = []

      before_create do
        init_cognito_user unless CognitoRails::Config.skip_model_hooks
      end

      after_destroy do
        destroy_cognito_user unless CognitoRails::Config.skip_model_hooks
      end
    end

    class_methods do
      # @return [Array<ActiveRecord::Base>] all users
      # @raise [CognitoRails::Error] if failed to fetch users
      # @raise [ActiveRecord::RecordInvalid] if failed to save user
      # @yield [user, user_data] yields user and user_data just before saving
      def sync_from_cognito!
        response = User.with_credentials(self).all
        response.users.map do |user_data|
          sync_user!(user_data) do |user|
            yield user, user_data if block_given?
          end
        end
      end

      # @return [Array<ActiveRecord::Base>] all users
      # @raise [CognitoRails::Error] if failed to fetch users
      # @raise [ActiveRecord::RecordInvalid] if failed to save user
      def sync_to_cognito!
        find_each.map do |user|
          user.init_cognito_user
          user.save!
        end
      end

      def sync_from_cognito_id!(external_id)
        user_data = User.with_credentials(self).find_raw(external_id)
        sync_user!(user_data) do |user|
          yield user, user_data if block_given?
        end
      end

      private

      def sync_user!(user_data)
        external_id = user_data.username
        return if external_id.blank?

        user = find_or_initialize_by(_cognito_attribute_name => external_id)
        attributes = user_data.respond_to?(:attributes) ? user_data.attributes : user_data.user_attributes
        user.email = User.extract_cognito_attribute(attributes, :email)
        user.phone = User.extract_cognito_attribute(attributes, :phone_number) if user.respond_to?(:phone)
        _cognito_resolve_custom_attribute(user, user_data)

        yield user if block_given?

        user.save!
        user
      end

      def _cognito_resolve_custom_attribute(user, user_data)
        _cognito_custom_attributes.each do |attribute|
          next if attribute[:value].is_a?(String)

          value = User.extract_cognito_attribute(user_data.attributes, attribute[:name])
          next unless value

          user[attribute[:name].gsub('custom:', '')] = value
        end
      end
    end

    # @return [String]
    def cognito_external_id
      self[self.class._cognito_attribute_name]
    end

    # @param value [String]
    # @return [String]
    def cognito_external_id=(value)
      self[self.class._cognito_attribute_name] = value
    end

    def cognito_user
      @cognito_user ||= cognito_scope.find(cognito_external_id)
    end

    protected

    def init_cognito_user
      return if cognito_external_id.present?

      cognito_user = cognito_scope.new(init_attributes)
      cognito_user.save!
      self.cognito_external_id = cognito_user.id
    end

    def init_attributes
      attrs = { email: email }
      attrs[:phone] = phone if respond_to?(:phone)
      attrs[:password] = password if respond_to?(:password)
      attrs[:custom_attributes] = instance_custom_attributes
      attrs[:verify_email] = self.class._cognito_verify_email
      attrs[:verify_phone] = self.class._cognito_verify_phone
      attrs[:password_policy] = self.class._cognito_password_policy
      attrs
    end

    # @return [Array<Hash>]
    def instance_custom_attributes
      _cognito_custom_attributes.map { |e| { name: e[:name], value: parse_custom_attribute_value(e[:value]) } }
    end

    def parse_custom_attribute_value(value)
      if value.is_a? Symbol
        self[value]
      else
        value
      end
    end

    def destroy_cognito_user
      cognito_user&.destroy!
    end

    def cognito_scope
      @cognito_scope ||= User.with_credentials(self.class)
    end

    class_methods do
      # @param name [String] attribute name
      # @return [ActiveRecord::Base] model class
      def find_by_cognito(external_id)
        find_by({ _cognito_attribute_name => external_id })
      end

      def cognito_verify_email
        self._cognito_verify_email = true
      end

      def cognito_verify_phone
        self._cognito_verify_phone = true
      end

      def cognito_password_policy(type)
        self._cognito_password_policy = type
      end

      # @param name [String] attribute name
      # @param value [String] attribute name
      def define_cognito_attribute(name, value)
        _cognito_custom_attributes << { name: "custom:#{name}", value: value }
      end
    end
  end
end
